// lib/core/utils/request_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Manages API requests with queuing, prioritization, and batch operations
class RequestManager {
  // Singleton pattern
  static final RequestManager _instance = RequestManager._internal();
  factory RequestManager() => _instance;
  RequestManager._internal();

  // Request tracking with priorities
  final Map<String, _QueuedRequest> _pendingRequests = {};
  final Map<String, CancellationToken> _activeTokens = {};
  final Map<RequestPriority, Queue<_QueuedRequest>> _requestQueues = {
    RequestPriority.high: Queue<_QueuedRequest>(),
    RequestPriority.normal: Queue<_QueuedRequest>(),
    RequestPriority.low: Queue<_QueuedRequest>(),
  };

  // Batch operations management
  final Map<String, _BatchOperation> _batchOperations = {};

  // Rate limiting
  final Map<String, DateTime> _requestTimestamps = {};
  static const Duration _minRequestInterval = Duration(milliseconds: 100);

  // Queue processing
  Timer? _queueProcessor;
  bool _isProcessingQueue = false;
  bool _disposed = false;

  // Constants
  static const _maxConcurrentRequests = 4;
  static const _defaultTimeout = Duration(seconds: 30);
  static const _maxRetries = 3;
  static const _batchDelay = Duration(milliseconds: 500);

  /// Execute a request with priority and retry mechanism
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

    final completer = Completer<T>();
    final token = cancellationToken ?? CancellationToken();
    _activeTokens[id] = token;

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

      // Add to appropriate queue
      _pendingRequests[id] = queuedRequest;
      _requestQueues[priority]!.add(queuedRequest);

      // Start queue processing if not already running
      _startQueueProcessing();

      return await completer.future;
    } catch (e) {
      _activeTokens.remove(id);
      rethrow;
    }
  }

  /// Start processing the request queue
  void _startQueueProcessing() {
    if (_isProcessingQueue || _disposed) return;

    _isProcessingQueue = true;
    _queueProcessor?.cancel();
    _queueProcessor = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _processRequestQueues(),
    );
  }

  /// Process requests from queues based on priority
  Future<void> _processRequestQueues() async {
    if (_disposed) return;

    // Count active requests
    final activeRequests = _pendingRequests.values
        .where((r) => r.status == RequestStatus.inProgress)
        .length;

    if (activeRequests >= _maxConcurrentRequests) return;

    // Process queues in priority order
    for (final priority in RequestPriority.values) {
      final queue = _requestQueues[priority]!;
      while (queue.isNotEmpty) {
        final request = queue.first;

        // Skip if already processing or cancelled
        if (request.status != RequestStatus.pending ||
            request.cancellationToken.isCancelled) {
          queue.removeFirst();
          continue;
        }

        // Check rate limiting
        if (!_canProcessRequest(request.id)) {
          break;
        }

        // Process request
        queue.removeFirst();
        _processRequest(request);

        // Check concurrent request limit
        if (activeRequests + 1 >= _maxConcurrentRequests) {
          return;
        }
      }
    }

    // Stop processor if all queues are empty
    if (_requestQueues.values.every((q) => q.isEmpty)) {
      _stopQueueProcessor();
    }
  }

  /// Process individual request with retry logic
  Future<void> _processRequest(_QueuedRequest request) async {
    if (_disposed || request.cancellationToken.isCancelled) return;

    try {
      request.status = RequestStatus.inProgress;

      if (kDebugMode) {
        print(
            '⚡ Processing request: ${request.id} (Attempt: ${request.retryCount + 1})');
      }

      // Execute with timeout
      final result = await _executeWithTimeout(
        request.execute,
        timeout: request.timeout,
        token: request.cancellationToken,
      );

      // Complete successfully
      request.completer.complete(result);
      _cleanupRequest(request.id);

      if (kDebugMode) {
        print('✅ Request completed: ${request.id}');
      }
    } catch (e) {
      await _handleRequestError(request, e);
    }
  }

  /// Execute operation with timeout
  Future<T> _executeWithTimeout<T>(
    Future<T> Function() operation, {
    required Duration timeout,
    required CancellationToken token,
  }) async {
    try {
      return await operation().timeout(timeout);
    } on TimeoutException {
      token.cancel();
      throw const RequestTimeoutException();
    }
  }

  /// Handle request errors and retry logic
  Future<void> _handleRequestError(
    _QueuedRequest request,
    dynamic error,
  ) async {
    if (request.cancellationToken.isCancelled) {
      request.completer.completeError(const RequestCancelledException());
      _cleanupRequest(request.id);
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
      request.completer.completeError(error);
      _cleanupRequest(request.id);

      if (kDebugMode) {
        print('❌ Request failed: ${request.id} - $error');
      }
    }
  }

  /// Check if error is retryable
  bool _shouldRetry(dynamic error) {
    // Retry on timeout and certain network errors
    return error is TimeoutException ||
        error is RequestTimeoutException ||
        (error is Exception && !error.toString().contains('cancelled'));
  }

  /// Check if request can be processed (rate limiting)
  bool _canProcessRequest(String id) {
    final lastRequest = _requestTimestamps[id];
    if (lastRequest == null) return true;

    return DateTime.now().difference(lastRequest) >= _minRequestInterval;
  }

  /// Track request timestamp for rate limiting
  void _updateRequestTimestamp(String id) {
    _requestTimestamps[id] = DateTime.now();
    _cleanOldTimestamps();
  }

  /// Clean old timestamps
  void _cleanOldTimestamps() {
    final now = DateTime.now();
    _requestTimestamps.removeWhere(
      (_, timestamp) => now.difference(timestamp) > const Duration(minutes: 1),
    );
  }

  /// Stop queue processor
  void _stopQueueProcessor() {
    _queueProcessor?.cancel();
    _queueProcessor = null;
    _isProcessingQueue = false;
  }

  /// Clean up request resources
  void _cleanupRequest(String id) {
    _pendingRequests.remove(id);
    _activeTokens.remove(id);
    _updateRequestTimestamp(id);
  }

  /// Create a batch operation
  BatchOperation createBatch() {
    final id = 'batch_${DateTime.now().millisecondsSinceEpoch}';
    final batch = _BatchOperation(
      id: id,
      onCommit: (operations) async {
        return _executeBatch(id, operations);
      },
    );
    _batchOperations[id] = batch;
    return batch;
  }

  /// Execute batch operations
  Future<List<dynamic>> _executeBatch(
    String id,
    List<Future<dynamic> Function()> operations,
  ) async {
    try {
      if (kDebugMode) {
        print('📦 Executing batch: $id (${operations.length} operations)');
      }

      final results = <dynamic>[];
      for (final operation in operations) {
        // Add small delay between operations
        if (results.isNotEmpty) {
          await Future.delayed(_batchDelay);
        }
        results.add(await operation());
      }

      _batchOperations.remove(id);
      return results;
    } catch (e) {
      _batchOperations.remove(id);
      rethrow;
    }
  }

  /// Cancel specific request
  void cancelRequest(String id) {
    final token = _activeTokens[id];
    if (token != null) {
      token.cancel();
      _activeTokens.remove(id);
    }

    final request = _pendingRequests[id];
    if (request != null) {
      request.completer.completeError(const RequestCancelledException());
      _cleanupRequest(id);
    }
  }

  /// Cancel all requests
  void cancelAllRequests() {
    for (final token in _activeTokens.values) {
      token.cancel();
    }

    for (final request in _pendingRequests.values) {
      request.completer.completeError(const RequestCancelledException());
    }

    _pendingRequests.clear();
    _activeTokens.clear();
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

  /// Cleanup resources
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    cancelAllRequests();
    _stopQueueProcessor();
    _batchOperations.clear();
    _requestTimestamps.clear();
  }
}

/// Request priority levels
enum RequestPriority {
  high,
  normal,
  low,
}

/// Request status
enum RequestStatus {
  pending,
  inProgress,
  completed,
  failed,
}

/// Queued request
class _QueuedRequest<T> {
  final String id;
  final RequestPriority priority;
  final Future<T> Function() execute;
  final Completer<T> completer;
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

/// Batch operation
class BatchOperation {
  final String id;
  final List<Future<dynamic> Function()> _operations = [];
  final Future<List<dynamic>> Function(List<Future<dynamic> Function()>)
      _onCommit;

  BatchOperation({
    required this.id,
    required Future<List<dynamic>> Function(List<Future<dynamic> Function()>)
        onCommit,
  }) : _onCommit = onCommit;

  void add(Future<dynamic> Function() operation) {
    _operations.add(operation);
  }

  Future<List<dynamic>> commit() {
    return _onCommit(_operations);
  }
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

/// Cancellation token
class CancellationToken {
  bool _isCancelled = false;
  final List<VoidCallback> _listeners = [];

  bool get isCancelled => _isCancelled;

  void cancel() {
    if (!_isCancelled) {
      _isCancelled = true;
      for (final listener in _listeners) {
        listener();
      }
    }
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
}
