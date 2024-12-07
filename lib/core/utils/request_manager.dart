// lib/core/utils/request_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:async/async.dart';

/// Manages API requests with improved queuing, prioritization, and batch operations.
/// Includes fair scheduling, memory management, and thread-safe operations.
class RequestManager {
  // Singleton pattern with proper initialization
  static final RequestManager _instance = RequestManager._internal();
  factory RequestManager() => _instance;
  RequestManager._internal() {
    _initializeScheduler();
  }

  // Request tracking with improved memory management
  final Map<String, _QueuedRequest> _pendingRequests = {};
  final Map<String, CancellationToken> _activeTokens = {};
  final Map<RequestPriority, Queue<_QueuedRequest>> _requestQueues = {
    RequestPriority.high: Queue<_QueuedRequest>(),
    RequestPriority.normal: Queue<_QueuedRequest>(),
    RequestPriority.low: Queue<_QueuedRequest>(),
  };

  // Thread-safe token management
  final _tokenLock = Lock();

  // Batch operations with transaction support
  final Map<String, _BatchTransaction> _batchOperations = {};

  // Fair scheduling implementation
  late final _FairScheduler _scheduler;
  Timer? _queueProcessor;
  bool _isProcessingQueue = false;
  bool _disposed = false;

  // Request lifecycle management
  final _lifecycleManager = _RequestLifecycleManager(
    maxLifetime: const Duration(minutes: 5),
    cleanupInterval: const Duration(minutes: 1),
  );

  // Constants
  static const _maxConcurrentRequests = 4;
  static const _defaultTimeout = Duration(seconds: 30);
  static const _maxRetries = 3;
  static const _batchDelay = Duration(milliseconds: 500);

  /// Initialize fair scheduler
  void _initializeScheduler() {
    _scheduler = _FairScheduler(
      quotas: {
        RequestPriority.high: 4,
        RequestPriority.normal: 2,
        RequestPriority.low: 1,
      },
      timeWindow: const Duration(seconds: 10),
    );
  }

  /// Execute a request with improved priority handling and retry mechanism
  Future<T> executeRequest<T>({
    required String id,
    required Future<T> Function() request,
    RequestPriority priority = RequestPriority.normal,
    Duration timeout = _defaultTimeout,
    int maxRetries = _maxRetries,
    CancellationToken? cancellationToken,
  }) async {
    _throwIfDisposed();

    // Check for duplicate request
    if (_pendingRequests.containsKey(id)) {
      throw const RequestAlreadyInProgressException();
    }

    final completer = CancelableCompleter<T>();
    final token = cancellationToken ?? CancellationToken();

    await _tokenLock.synchronized(() async {
      for (final token in _activeTokens.values) {
        token.cancel();
      }
      _activeTokens.clear();
      return;
      _activeTokens[id] = token;
    });

    try {
      if (kDebugMode) {
        print('🚀 Executing request: $id (Priority: $priority)');
      }

      final queuedRequest = _QueuedRequest(
        id: id,
        priority: priority,
        execute: request,
        completer: completer,
        maxRetries: maxRetries,
        timeout: timeout,
        cancellationToken: token,
        timestamp: DateTime.now(),
      );

      // Add to queue with lifecycle management
      _lifecycleManager.trackRequest(queuedRequest);
      _pendingRequests[id] = queuedRequest;
      _requestQueues[priority]!.add(queuedRequest);

      // Start queue processing if not already running
      _startQueueProcessing();

      return await completer.operation.value;
    } catch (e) {
      await _tokenLock.synchronized(() async {
        _activeTokens.remove(id);
        return;
      });
      rethrow;
    }
  }

  /// Start processing the request queue with fair scheduling
  void _startQueueProcessing() {
    if (_isProcessingQueue || _disposed) return;

    _isProcessingQueue = true;
    _queueProcessor?.cancel();
    _queueProcessor = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _processRequestQueues(),
    );
  }

  /// Process requests with fair scheduling and priority handling
  Future<void> _processRequestQueues() async {
    if (_disposed) return;

    final activeRequests = _pendingRequests.values
        .where((r) => r.status == RequestStatus.inProgress)
        .length;

    if (activeRequests >= _maxConcurrentRequests) return;

    // Get next priority from fair scheduler
    final nextPriority = _scheduler.getNextPriority();
    if (nextPriority == null) return;

    final queue = _requestQueues[nextPriority]!;

    while (queue.isNotEmpty && activeRequests < _maxConcurrentRequests) {
      final request = queue.first;

      // Skip if cancelled or expired
      if (_lifecycleManager.isExpired(request) ||
          request.cancellationToken.isCancelled) {
        queue.removeFirst();
        continue;
      }

      // Process request
      queue.removeFirst();
      unawaited(_processRequest(request));

      if (queue.isEmpty || activeRequests + 1 >= _maxConcurrentRequests) {
        break;
      }
    }

    // Stop processor if all queues are empty
    if (_requestQueues.values.every((q) => q.isEmpty)) {
      _stopQueueProcessing();
    }
  }

  /// Process individual request with improved error handling
  Future<void> _processRequest(_QueuedRequest request) async {
    if (_disposed || request.cancellationToken.isCancelled) return;

    try {
      request.status = RequestStatus.inProgress;

      if (kDebugMode) {
        print(
            '⚡ Processing request: ${request.id} (Attempt: ${request.retryCount + 1})');
      }

      // Execute with timeout and cancellation
      final result = await _executeWithTimeout(
        request.execute,
        timeout: request.timeout,
        token: request.cancellationToken,
      );

      // Complete successfully
      if (!request.completer.isCompleted && !request.completer.isCanceled) {
        request.completer.complete(result);
      }

      await _cleanupRequest(request.id);

      if (kDebugMode) {
        print('✅ Request completed: ${request.id}');
      }
    } catch (e) {
      await _handleRequestError(request, e);
    }
  }

  /// Execute operation with timeout and cancellation support
  Future<T> _executeWithTimeout<T>(
    Future<T> Function() operation, {
    required Duration timeout,
    required CancellationToken token,
  }) async {
    try {
      final result = await operation().timeout(timeout);
      token.throwIfCancelled();
      return result;
    } on TimeoutException {
      token.cancel();
      throw const RequestTimeoutException();
    }
  }

  /// Handle request errors with improved retry logic
  Future<void> _handleRequestError(
    _QueuedRequest request,
    dynamic error,
  ) async {
    if (request.cancellationToken.isCancelled) {
      if (!request.completer.isCompleted && !request.completer.isCanceled) {
        request.completer.completeError(const RequestCancelledException());
      }
      await _cleanupRequest(request.id);
      return;
    }

    // Check if should retry
    if (request.retryCount < request.maxRetries && _shouldRetry(error)) {
      request.retryCount++;
      request.status = RequestStatus.pending;

      // Add back to queue with exponential backoff
      final delay = Duration(milliseconds: 200 * (1 << request.retryCount));
      await Future.delayed(delay);

      _requestQueues[request.priority]!.add(request);

      if (kDebugMode) {
        print(
            '🔄 Queuing retry for: ${request.id} (Attempt: ${request.retryCount})');
      }
    } else {
      // Max retries reached or non-retryable error
      if (!request.completer.isCompleted && !request.completer.isCanceled) {
        request.completer.completeError(error);
      }
      await _cleanupRequest(request.id);

      if (kDebugMode) {
        print('❌ Request failed: ${request.id} - $error');
      }
    }
  }

  /// Check if error is retryable
  bool _shouldRetry(dynamic error) {
    return error is TimeoutException ||
        error is RequestTimeoutException ||
        (error is Exception && !error.toString().contains('cancelled'));
  }

  /// Clean up request resources safely
  Future<void> _cleanupRequest(String id) async {
    _pendingRequests.remove(id);
    await _tokenLock.synchronized(() async {
      _activeTokens.remove(id);
      return;
    });
    _lifecycleManager.removeRequest(id);
    return;
  }

  /// Stop queue processor
  void _stopQueueProcessing() {
    _queueProcessor?.cancel();
    _queueProcessor = null;
    _isProcessingQueue = false;
  }

  /// Create a batch operation with transaction support
  BatchOperation createBatch() {
    final id = 'batch_${DateTime.now().millisecondsSinceEpoch}';
    final batch = _BatchTransaction(
      id: id,
      onCommit: (operations) async {
        return _executeBatch(id, operations);
      },
      onRollback: (operations) async {
        return _rollbackBatch(id, operations);
      },
    );
    _batchOperations[id] = batch;
    return batch;
  }

  /// Execute batch operations with transaction support
  Future<List<dynamic>> _executeBatch(
    String id,
    List<Future<dynamic> Function()> operations,
  ) async {
    final results = <dynamic>[];
    final batch = _batchOperations[id]!;

    try {
      if (kDebugMode) {
        print('📦 Executing batch: $id (${operations.length} operations)');
      }

      for (var i = 0; i < operations.length; i++) {
        try {
          final operation = operations[i];

          // Add small delay between operations
          if (i > 0) {
            await Future.delayed(_batchDelay);
          }

          final result = await operation();
          results.add(result);
          batch.successfulOperations.add(i);
        } catch (e) {
          // On failure, rollback successful operations
          if (batch.successfulOperations.isNotEmpty) {
            await _rollbackBatch(id, operations);
          }
          rethrow;
        }
      }

      _batchOperations.remove(id);
      return results;
    } catch (e) {
      _batchOperations.remove(id);
      rethrow;
    }
  }

  /// Rollback batch operations on failure
  Future<void> _rollbackBatch(
    String id,
    List<Future<dynamic> Function()> operations,
  ) async {
    final batch = _batchOperations[id]!;

    try {
      if (kDebugMode) {
        print('↩️ Rolling back batch: $id');
      }

      // Execute rollback operations in reverse order
      for (final index in batch.successfulOperations.toList().reversed) {
        if (index < operations.length) {
          try {
            await operations[index]();
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Rollback operation failed: $e');
            }
          }
        }
      }
    } finally {
      _batchOperations.remove(id);
    }
  }

  /// Cancel specific request safely
  Future<void> cancelRequest(String id) async {
    await _tokenLock.synchronized(() async {
      final token = _activeTokens[id];
      if (token != null) {
        token.cancel();
        _activeTokens.remove(id);
      }
    });

    final request = _pendingRequests[id];
    if (request != null) {
      if (!request.completer.isCompleted && !request.completer.isCanceled) {
        request.completer.completeError(const RequestCancelledException());
      }
      await _cleanupRequest(id);
    }
  }

  /// Cancel all requests safely
  Future<void> cancelAllRequests() async {
    await _tokenLock.synchronized(() async {
      for (final token in _activeTokens.values) {
        token.cancel();
      }
      _activeTokens.clear();
    });

    for (final request in _pendingRequests.values) {
      if (!request.completer.isCompleted && !request.completer.isCanceled) {
        request.completer.completeError(const RequestCancelledException());
      }
    }

    _pendingRequests.clear();
    for (final queue in _requestQueues.values) {
      queue.clear();
    }
  }

  /// Check if disposed
  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError('RequestManager has been disposed');
    }
  }

  /// Cleanup resources safely
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;
    await cancelAllRequests();
    _stopQueueProcessing();
    _batchOperations.clear();
    _lifecycleManager.dispose();
  }
}

/// Request priority levels
enum RequestPriority {
  high,
  normal,
  low,
}

/// Request status tracking
enum RequestStatus {
  pending,
  inProgress,
  completed,
  failed,
}

/// Queued request with improved tracking
class _QueuedRequest<T> {
  final String id;
  final RequestPriority priority;
  final Future<T> Function() execute;
  final CancelableCompleter<T> completer;
  final int maxRetries;
  final Duration timeout;
  final CancellationToken cancellationToken;
  final DateTime timestamp;

  RequestStatus status = RequestStatus.pending;
  int retryCount = 0;

  _QueuedRequest({
    required this.id,
    required this.priority,
    required this.execute,
    required this.completer,
    required this.maxRetries,
    required this.timeout,
    required this.cancellationToken,
    required this.timestamp,
  });
}

/// Fair scheduler implementation
class _FairScheduler {
  final Map<RequestPriority, int> _quotas;
  final Duration timeWindow;
  final Map<RequestPriority, int> _usage = {};
  DateTime _lastReset = DateTime.now();

  _FairScheduler({
    required Map<RequestPriority, int> quotas,
    required this.timeWindow,
  }) : _quotas = quotas {
    _resetUsage();
  }

  void _resetUsage() {
    for (final priority in RequestPriority.values) {
      _usage[priority] = 0;
    }
  }

  RequestPriority? getNextPriority() {
    // Check if we need to reset quotas
    if (DateTime.now().difference(_lastReset) >= timeWindow) {
      _resetUsage();
      _lastReset = DateTime.now();
    }

    // Find priority with available quota
    RequestPriority? selectedPriority;
    double bestRatio = 0;

    for (final priority in RequestPriority.values) {
      final quota = _quotas[priority] ?? 0;
      final used = _usage[priority] ?? 0;

      if (quota > 0) {
        final ratio = (quota - used) / quota;
        if (ratio > bestRatio) {
          bestRatio = ratio;
          selectedPriority = priority;
        }
      }
    }

    if (selectedPriority != null) {
      _usage[selectedPriority] = (_usage[selectedPriority] ?? 0) + 1;
    }

    return selectedPriority;
  }
}

/// Batch transaction with rollback support
class _BatchTransaction implements BatchOperation {
  final String id;
  final Future<List<dynamic>> Function(List<Future<dynamic> Function()>)
      _onCommit;
  final Future<void> Function(List<Future<dynamic> Function()>) _onRollback;
  final List<Future<dynamic> Function()> _operations = [];
  final Set<int> successfulOperations = <int>{};

  _BatchTransaction({
    required this.id,
    required Future<List<dynamic>> Function(List<Future<dynamic> Function()>)
        onCommit,
    required Future<void> Function(List<Future<dynamic> Function()>) onRollback,
  })  : _onCommit = onCommit,
        _onRollback = onRollback;

  @override
  void add(Future<dynamic> Function() operation) {
    _operations.add(operation);
  }

  @override
  Future<List<dynamic>> commit() {
    return _onCommit(_operations);
  }

  Future<void> rollback() {
    return _onRollback(_operations);
  }
}

/// Request lifecycle management
class _RequestLifecycleManager {
  final Duration maxLifetime;
  final Duration cleanupInterval;
  final Map<String, DateTime> _requestTimestamps = {};
  Timer? _cleanupTimer;

  _RequestLifecycleManager({
    required this.maxLifetime,
    required this.cleanupInterval,
  }) {
    _startCleanupTimer();
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(cleanupInterval, (_) => _cleanup());
  }

  void trackRequest(_QueuedRequest request) {
    _requestTimestamps[request.id] = request.timestamp;
  }

  void removeRequest(String id) {
    _requestTimestamps.remove(id);
  }

  bool isExpired(_QueuedRequest request) {
    final timestamp = _requestTimestamps[request.id];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) > maxLifetime;
  }

  void _cleanup() {
    final now = DateTime.now();
    _requestTimestamps
        .removeWhere((_, timestamp) => now.difference(timestamp) > maxLifetime);
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _requestTimestamps.clear();
  }
}

/// Thread-safe lock implementation
class Lock {
  Completer<void>? _completer;
  bool _locked = false;

  Future<T> synchronized<T>(Future<T> Function() operation) async {
    while (_locked) {
      await _completer?.future;
    }

    _locked = true;
    final completer = Completer<void>();

    try {
      return await operation();
    } finally {
      _locked = false;
      completer.complete();
    }
  }
}

/// Batch operation interface
abstract class BatchOperation {
  void add(Future<dynamic> Function() operation);
  Future<List<dynamic>> commit();
}

/// Request exceptions
class RequestAlreadyInProgressException implements Exception {
  const RequestAlreadyInProgressException();

  @override
  String toString() => 'Request is already in progress';
}

class RequestCancelledException implements Exception {
  const RequestCancelledException();

  @override
  String toString() => 'Request was cancelled';
}

class RequestTimeoutException implements Exception {
  const RequestTimeoutException();

  @override
  String toString() => 'Request timed out';
}

/// Cancellation token implementation
class CancellationToken {
  bool _isCancelled = false;
  final List<VoidCallback> _listeners = [];

  bool get isCancelled => _isCancelled;

  void cancel() {
    if (!_isCancelled) {
      _isCancelled = true;
      for (final listener in List<VoidCallback>.from(_listeners)) {
        listener();
      }
      _listeners.clear();
    }
  }

  void addListener(VoidCallback listener) {
    if (!_isCancelled) {
      _listeners.add(listener);
    } else {
      listener();
    }
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw const RequestCancelledException();
    }
  }
}
