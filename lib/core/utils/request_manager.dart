// lib/core/utils/request_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import './cancellation_token.dart';
import './rate_limiter.dart';

/// Manages API requests with improved queuing, prioritization, and batch operations
class RequestManager {
  // Singleton pattern with proper initialization
  static final RequestManager _instance = RequestManager._internal();
  factory RequestManager() => _instance;

  // Request tracking with memory management
  final Map<String, _QueuedRequest> _pendingRequests = {};
  final Map<String, CancellationToken> _activeTokens = {};
  final Map<RequestPriority, Queue<_QueuedRequest>> _requestQueues = {
    RequestPriority.high: Queue<_QueuedRequest>(),
    RequestPriority.normal: Queue<_QueuedRequest>(),
    RequestPriority.low: Queue<_QueuedRequest>(),
  };

  // Thread-safe token management
  final _lock = Lock();

  // Batch operations with transaction support
  final Map<String, _BatchTransaction> _batchOperations = {};

  // Rate limiting
  final _rateLimiter = RateLimiter();

  // State management
  bool _isProcessingQueue = false;
  bool _disposed = false;
  Timer? _queueProcessor;

  // Constants
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxConcurrentRequests = 4;
  static const int _maxRetries = 3;
  static const Duration _batchDelay = Duration(milliseconds: 500);

  RequestManager._internal();

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

    await _lock.synchronized(() async {
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

      final queuedRequest = _QueuedRequest(
        id: id,
        priority: priority,
        execute: request,
        completer: completer,
        maxRetries: maxRetries,
        timeout: timeout,
        cancellationToken: token,
      );

      // Add to queue with proper priority
      _pendingRequests[id] = queuedRequest;
      _requestQueues[priority]!.add(queuedRequest);

      // Start queue processing if not already running
      _startQueueProcessing();

      return await completer.operation.value.timeout(timeout);
    } catch (e) {
      await _lock.synchronized(() async {
        _activeTokens.remove(id);
      });
      rethrow;
    }
  }

  /// Process requests with fair scheduling and priority handling
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
      _QueuedRequest request, dynamic error) async {
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

  /// Clean up request resources safely
  Future<void> _cleanupRequest(String id) async {
    _pendingRequests.remove(id);
    await _lock.synchronized(() async {
      _activeTokens.remove(id);
    });
  }

  /// Cancel all requests safely
  Future<void> cancelAllRequests() async {
    await _lock.synchronized(() async {
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

  /// Resource cleanup
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;
    await cancelAllRequests();
    _queueProcessor?.cancel();
    _batchOperations.clear();
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
enum RequestStatus { pending, inProgress, completed, failed }

/// Custom exceptions for better error handling
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
