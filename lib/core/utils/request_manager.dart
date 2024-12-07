// lib/core/utils/request_manager.dart

// lib/core/utils/request_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

class RequestManager {
  // Singleton instance
  static final RequestManager _instance = RequestManager._internal();
  factory RequestManager() => _instance;
  RequestManager._internal();

  // Request tracking
  final Map<String, _QueuedRequest> _pendingRequests = {};
  final Queue<_QueuedRequest> _retryQueue = Queue<_QueuedRequest>();
  final Map<String, CancellationToken> _activeTokens = {};

  // Rate limiting
  final Map<String, DateTime> _requestTimestamps = {};
  static const Duration _minRequestInterval = Duration(milliseconds: 100);

  // Queue processing
  Timer? _retryTimer;
  bool _isProcessingQueue = false;

  // Method to execute request with retry mechanism
  Future<T> executeRequest<T>({
    required String id,
    required Future<T> Function() request,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
    Duration? retryDelay,
    CancellationToken? cancellationToken,
  }) async {
    // Check if request exists
    if (_pendingRequests.containsKey(id)) {
      throw const RequestAlreadyInProgressException();
    }

    final completer = Completer<T>();
    final token = cancellationToken ?? CancellationToken();
    _activeTokens[id] = token;

    try {
      if (kDebugMode) {
        print('🚀 Executing request: $id');
      }

      // Create queued request
      final queuedRequest = _QueuedRequest(
        id: id,
        execute: request,
        completer: completer,
        maxRetries: maxRetries,
        retryDelay: retryDelay ?? const Duration(seconds: 2),
        timeout: timeout,
        cancellationToken: token,
      );

      _pendingRequests[id] = queuedRequest;

      // Check rate limiting
      await _waitForRateLimit();

      // Execute request
      final result = await _executeWithTimeout(
        queuedRequest.execute,
        timeout: timeout,
        token: token,
      );

      completer.complete(result);
      _updateRequestTimestamp(id);
      _pendingRequests.remove(id);

      if (kDebugMode) {
        print('✅ Request completed: $id');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Request failed: $id - $e');
      }

      if (e is! RequestCancelledException) {
        await _handleRequestError(id, e, completer);
      } else {
        completer.completeError(e);
        _pendingRequests.remove(id);
      }
    } finally {
      _activeTokens.remove(id);
    }

    return completer.future;
  }

  // Execute with timeout
  Future<T> _executeWithTimeout<T>(
    Future<T> Function() request, {
    required Duration timeout,
    required CancellationToken token,
  }) async {
    try {
      final result = await request().timeout(timeout);
      return result;
    } on TimeoutException {
      token.cancel();
      throw TimeoutException('Request timed out');
    }
  }

  // Handle request error
  Future<void> _handleRequestError(
    String id,
    dynamic error,
    Completer completer,
  ) async {
    final request = _pendingRequests[id];
    if (request == null) return;

    if (request.retryCount < request.maxRetries) {
      // Add to retry queue
      request.retryCount++;
      if (kDebugMode) {
        print(
            '🔄 Queueing retry for request: $id (Attempt ${request.retryCount})');
      }
      _retryQueue.add(request);
      _startQueueProcessing();
    } else {
      if (kDebugMode) {
        print('❌ Request failed after ${request.maxRetries} retries: $id');
      }
      completer.completeError(error);
      _pendingRequests.remove(id);
    }
  }

  // Process retry queue
  void _startQueueProcessing() {
    if (_isProcessingQueue) return;

    _isProcessingQueue = true;
    _retryTimer?.cancel();

    _retryTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _processRetryQueue(),
    );
  }

  Future<void> _processRetryQueue() async {
    if (_retryQueue.isEmpty) {
      _retryTimer?.cancel();
      _isProcessingQueue = false;
      return;
    }

    final request = _retryQueue.first;

    // Check if we should retry now
    if (DateTime.now().difference(request.lastAttemptTime) <
        request.retryDelay) {
      return;
    }

    _retryQueue.removeFirst();

    try {
      if (kDebugMode) {
        print('🔄 Retrying request: ${request.id}');
      }

      request.lastAttemptTime = DateTime.now();

      final result = await _executeWithTimeout(
        request.execute,
        timeout: request.timeout,
        token: request.cancellationToken,
      );

      request.completer.complete(result);
      _pendingRequests.remove(request.id);

      if (kDebugMode) {
        print('✅ Retry successful: ${request.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Retry failed: ${request.id} - $e');
      }
      await _handleRequestError(request.id, e, request.completer);
    }
  }

  // Rate limiting
  Future<void> _waitForRateLimit() async {
    if (_requestTimestamps.isEmpty) return;

    final lastRequestTime = _requestTimestamps.values.reduce(
      (a, b) => a.isAfter(b) ? a : b,
    );
    final timeSinceLastRequest = DateTime.now().difference(lastRequestTime);

    if (timeSinceLastRequest < _minRequestInterval) {
      await Future.delayed(_minRequestInterval - timeSinceLastRequest);
    }
  }

  void _updateRequestTimestamp(String id) {
    _requestTimestamps[id] = DateTime.now();
    _cleanOldTimestamps();
  }

  void _cleanOldTimestamps() {
    final now = DateTime.now();
    _requestTimestamps.removeWhere(
      (_, timestamp) => now.difference(timestamp) > const Duration(minutes: 1),
    );
  }

  // Retry failed requests (called from ConnectivityManager)
  Future<void> retryFailedRequests() async {
    if (kDebugMode) {
      print('🔄 Retrying all failed requests');
    }

    final retryRequests = List<_QueuedRequest>.from(_retryQueue);
    _retryQueue.clear();

    for (final request in retryRequests) {
      try {
        if (request.cancellationToken.isCancelled) continue;

        final result = await _executeWithTimeout(
          request.execute,
          timeout: request.timeout,
          token: request.cancellationToken,
        );

        request.completer.complete(result);
        _pendingRequests.remove(request.id);

        if (kDebugMode) {
          print('✅ Retry successful: ${request.id}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Retry failed: ${request.id} - $e');
        }
        await _handleRequestError(request.id, e, request.completer);
      }
    }
  }

  // Cancel specific request
  void cancelRequest(String id) {
    final token = _activeTokens[id];
    if (token != null) {
      token.cancel();
      _activeTokens.remove(id);
    }

    // Remove from retry queue
    _retryQueue.removeWhere((request) {
      if (request.id == id) {
        request.completer.completeError(const RequestCancelledException());
        return true;
      }
      return false;
    });

    _pendingRequests.remove(id);
  }

  // Cancel all requests
  void cancelAllRequests() {
    for (final token in _activeTokens.values) {
      token.cancel();
    }
    _activeTokens.clear();

    for (final request in _pendingRequests.values) {
      request.completer.completeError(const RequestCancelledException());
    }
    _pendingRequests.clear();
    _retryQueue.clear();
  }

  // Cleanup resources
  void dispose() {
    cancelAllRequests();
    _retryTimer?.cancel();
    _requestTimestamps.clear();
  }
}

// Request queue item
class _QueuedRequest<T> {
  final String id;
  final Future<T> Function() execute;
  final Completer<T> completer;
  final int maxRetries;
  final Duration retryDelay;
  final Duration timeout;
  final CancellationToken cancellationToken;

  int retryCount = 0;
  DateTime lastAttemptTime = DateTime.now();

  _QueuedRequest({
    required this.id,
    required this.execute,
    required this.completer,
    required this.maxRetries,
    required this.retryDelay,
    required this.timeout,
    required this.cancellationToken,
  });
}

// Custom exceptions
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

// Cancellation token
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
