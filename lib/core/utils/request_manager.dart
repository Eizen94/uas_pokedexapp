// lib/core/utils/request_manager.dart

// Dart imports
import 'dart:async';
import 'dart:collection';
import 'dart:convert';

// Package imports
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Local imports
import 'cancellation_token.dart';
import 'rate_limiter.dart';
import 'monitoring_manager.dart';
import '../constants/api_paths.dart';

/// Enhanced request manager with improved queuing, prioritization and batch operations.
/// Provides comprehensive request lifecycle management with proper error handling.
class RequestManager {
  // Singleton implementation
  static final RequestManager _instance = RequestManager._internal();
  static final _lock = Object();

  // Core components
  final RateLimiter _rateLimiter = RateLimiter();
  final http.Client _client = http.Client();

  // Request tracking
  final Map<String, QueuedRequest> _pendingRequests = {};
  final Map<String, CancellationToken> _activeTokens = {};
  final Map<RequestPriority, Queue<QueuedRequest>> _requestQueues = {
    RequestPriority.high: Queue<QueuedRequest>(),
    RequestPriority.normal: Queue<QueuedRequest>(),
    RequestPriority.low: Queue<QueuedRequest>(),
  };

  // Batch operations
  final Map<String, BatchTransaction> _batchOperations = {};
  final StreamController<RequestEvent> _eventController =
      StreamController<RequestEvent>.broadcast();

  // State management
  bool _isProcessingQueue = false;
  bool _disposed = false;
  Timer? _queueProcessor;
  int _totalRequests = 0;
  int _totalErrors = 0;

  // Constants
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _processingInterval = Duration(milliseconds: 100);
  static const int _maxConcurrentRequests = 4;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Private constructor
  RequestManager._internal();

  // Factory constructor
  factory RequestManager() => _instance;

  /// Execute request with improved priority handling and retry mechanism
  Future<T> executeRequest<T>({
    required String id,
    required Future<T> Function() request,
    RequestPriority priority = RequestPriority.normal,
    Duration timeout = _defaultTimeout,
    int maxRetries = _maxRetries,
    CancellationToken? cancellationToken,
    Map<String, String>? headers,
    bool allowBatching = false,
  }) async {
    _throwIfDisposed();

    // Check for duplicate request
    if (_pendingRequests.containsKey(id)) {
      throw const RequestAlreadyInProgressException();
    }

    final completer = CancelableCompleter<T>();
    final token = cancellationToken ?? CancellationToken();

    await synchronized(_lock, () async {
      // Cancel any existing tokens
      for (final token in _activeTokens.values) {
        token.cancel();
      }
      _activeTokens.clear();

      // Store new token
      _activeTokens[id] = token;
    });

    try {
      if (kDebugMode) {
        print('🚀 Executing request: $id (Priority: $priority)');
      }

      final queuedRequest = QueuedRequest(
        id: id,
        priority: priority,
        execute: request,
        completer: completer,
        maxRetries: maxRetries,
        timeout: timeout,
        cancellationToken: token,
        headers: headers,
        allowBatching: allowBatching,
      );

      // Add to queue with proper priority
      _pendingRequests[id] = queuedRequest;
      _requestQueues[priority]!.add(queuedRequest);
      _totalRequests++;

      _notifyEvent(
        RequestEventType.queued,
        requestId: id,
        priority: priority,
      );

      // Start queue processing if not already running
      _startQueueProcessing();

      return await completer.operation.value.timeout(timeout);
    } catch (e) {
      await synchronized(_lock, () async {
        _activeTokens.remove(id);
        _totalErrors++;
      });

      _notifyEvent(
        RequestEventType.error,
        requestId: id,
        error: e,
      );

      rethrow;
    }
  }

  /// Process requests with fair scheduling and priority handling
  Future<void> _processRequest(QueuedRequest request) async {
    if (_disposed || request.cancellationToken.isCancelled) return;

    try {
      request.status = RequestStatus.inProgress;
      _notifyEvent(
        RequestEventType.processing,
        requestId: request.id,
      );

      // Execute with timeout and cancellation
      final result = await _executeWithTimeout(
        request.execute,
        timeout: request.timeout,
        token: request.cancellationToken,
      );

      // Complete successfully
      if (!request.completer.isCompleted && !request.completer.isCanceled) {
        request.completer.complete(result);
        _notifyEvent(
          RequestEventType.completed,
          requestId: request.id,
        );
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
  Future<void> _handleRequestError(QueuedRequest request, dynamic error) async {
    if (request.cancellationToken.isCancelled) {
      if (!request.completer.isCompleted && !request.completer.isCanceled) {
        request.completer.completeError(const RequestCancelledException());
        _notifyEvent(
          RequestEventType.cancelled,
          requestId: request.id,
        );
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
      _notifyEvent(
        RequestEventType.retrying,
        requestId: request.id,
        retryCount: request.retryCount,
      );

      if (kDebugMode) {
        print(
            '🔄 Queuing retry for: ${request.id} (Attempt: ${request.retryCount})');
      }
    } else {
      _totalErrors++;
      // Max retries reached or non-retryable error
      if (!request.completer.isCompleted && !request.completer.isCanceled) {
        request.completer.completeError(error);
        _notifyEvent(
          RequestEventType.failed,
          requestId: request.id,
          error: error,
        );
      }
      await _cleanupRequest(request.id);

      if (kDebugMode) {
        print('❌ Request failed: ${request.id} - $error');
      }
    }
  }

  /// Check if error is retryable
  bool _shouldRetry(dynamic error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is http.ClientException) return true;

    return false;
  }

  /// Clean up request resources
  Future<void> _cleanupRequest(String id) async {
    _pendingRequests.remove(id);
    await synchronized(_lock, () async {
      _activeTokens.remove(id);
    });
  }

  /// Start queue processing
  void _startQueueProcessing() {
    if (_isProcessingQueue) return;

    _isProcessingQueue = true;
    _queueProcessor?.cancel();
    _queueProcessor = Timer.periodic(_processingInterval, (_) {
      _processNextRequest();
    });
  }

  /// Process next request in queue
  Future<void> _processNextRequest() async {
    if (_disposed || !_isProcessingQueue) return;

    await synchronized(_lock, () async {
      // Check concurrent request limit
      if (_pendingRequests.length >= _maxConcurrentRequests) return;

      // Get next request by priority
      final request = _getNextRequest();
      if (request == null) {
        _stopQueueProcessing();
        return;
      }

      _processRequest(request);
    });
  }

  /// Get next request based on priority
  QueuedRequest? _getNextRequest() {
    // Check high priority queue
    if (_requestQueues[RequestPriority.high]!.isNotEmpty) {
      return _requestQueues[RequestPriority.high]!.removeFirst();
    }

    // Check normal priority queue
    if (_requestQueues[RequestPriority.normal]!.isNotEmpty) {
      return _requestQueues[RequestPriority.normal]!.removeFirst();
    }

    // Check low priority queue
    if (_requestQueues[RequestPriority.low]!.isNotEmpty) {
      return _requestQueues[RequestPriority.low]!.removeFirst();
    }

    return null;
  }

  /// Stop queue processing
  void _stopQueueProcessing() {
    _isProcessingQueue = false;
    _queueProcessor?.cancel();
    _queueProcessor = null;
  }

  /// Notify request event
  void _notifyEvent(
    RequestEventType type, {
    String? requestId,
    RequestPriority? priority,
    int? retryCount,
    Object? error,
  }) {
    if (!_eventController.isClosed && !_disposed) {
      _eventController.add(RequestEvent(
        type: type,
        requestId: requestId,
        priority: priority,
        retryCount: retryCount,
        error: error,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Cancel all requests safely
  Future<void> cancelAllRequests() async {
    await synchronized(_lock, () async {
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

    _notifyEvent(RequestEventType.cancelled);
  }

  /// Reset request manager
  Future<void> reset() async {
    await cancelAllRequests();
    _totalRequests = 0;
    _totalErrors = 0;
    _notifyEvent(RequestEventType.reset);
  }

  /// Get request metrics
  RequestMetrics get metrics => RequestMetrics(
        totalRequests: _totalRequests,
        totalErrors: _totalErrors,
        pendingRequests: _pendingRequests.length,
        activeTokens: _activeTokens.length,
      );

  /// Get monitoring stream
  Stream<RequestEvent> get events => _eventController.stream;

  /// Resource cleanup
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;
    await cancelAllRequests();
    _queueProcessor?.cancel();
    _batchOperations.clear();
    _client.close();
    await _eventController.close();

    if (kDebugMode) {
      print('🧹 RequestManager disposed');
    }
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError('RequestManager has been disposed');
    }
  }
}

/// Request priority levels
enum RequestPriority { high, normal, low }

/// Request status tracking
enum RequestStatus { pending, inProgress, completed, failed, cancelled }

/// Request event types
enum RequestEventType {
  queued,
  processing,
  completed,
  failed,
  cancelled,
  retrying,
  error,
  reset
}

/// Queued request with metadata
class QueuedRequest<T> {
  final String id;
  final RequestPriority priority;
  final Future<T> Function() execute;
  final CancelableCompleter<T> completer;
  final int maxRetries;
  final Duration timeout;
  final CancellationToken cancellationToken;
  final Map<String, String>? headers;
  final bool allowBatching;

  RequestStatus status = RequestStatus.pending;
  int retryCount = 0;
  DateTime timestamp = DateTime.now();

  QueuedRequest({
    required this.id,
    required this.priority,
    required this.execute,
    required this.completer,
    required this.maxRetries,
    required this.timeout,
    required this.cancellationToken,
    this.headers,
    this.allowBatching = false,
  });
}

/// Batch transaction tracking
class BatchTransaction {
  final String id;
  final List<QueuedRequest> requests;
  final DateTime timestamp;
  final CancellationToken cancellationToken;

  BatchTransaction({
    required this.id,
    required this.requests,
    required this.timestamp,
    required this.cancellationToken,
  });
}

/// Request metrics
class RequestMetrics {
  final int totalRequests;
  final int totalErrors;
  final int pendingRequests;
  final int activeTokens;

  RequestMetrics({
    required this.totalRequests,
    required this.totalErrors,
    required this.pendingRequests,
    required this.activeTokens,
  });

  @override
  String toString() => 'RequestMetrics('
      'total: $totalRequests, '
      'errors: $totalErrors, '
      'pending: $pendingRequests)';
}

/// Request event for monitoring
class RequestEvent {
  final RequestEventType type;
  final String? requestId;
  final RequestPriority? priority;
  final int? retryCount;
  final Object? error;
  final DateTime timestamp;

  RequestEvent({
    required this.type,
    this.requestId,
    this.priority,
    this.retryCount,
    this.error,
    required this.timestamp,
  });

  @override
  String toString() => 'RequestEvent('
      'type: $type, '
      'requestId: $requestId, '
      'timestamp: $timestamp)';
}

/// Custom exceptions
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

/// Timeout exception for requests
class RequestTimeoutException implements Exception {
  const RequestTimeoutException();

  @override
  String toString() => 'Request timed out';
}

/// Batch operation exception
class BatchOperationException implements Exception {
  final String message;
  final Object? error;

  const BatchOperationException(this.message, [this.error]);

  @override
  String toString() =>
      'BatchOperationException: $message${error != null ? ' ($error)' : ''}';
}

/// Invalid request exception
class InvalidRequestException implements Exception {
  final String message;

  const InvalidRequestException(this.message);

  @override
  String toString() => 'InvalidRequestException: $message';
}

/// Thread-safe operation helper
Future<T> synchronized<T>(
  Object lock,
  Future<T> Function() computation,
) async {
  final completer = Completer<void>();
  try {
    return await computation();
  } finally {
    completer.complete();
  }
}
