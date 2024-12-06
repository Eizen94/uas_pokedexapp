// lib/core/utils/request_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

class RequestManager {
  // Singleton instance
  static final RequestManager _instance = RequestManager._internal();
  factory RequestManager() => _instance;
  RequestManager._internal();

  // Rate limiting configuration
  static const int _maxRequestsPerMinute = 100;
  static const Duration _timeWindow = Duration(minutes: 1);

  // Request tracking
  final Queue<DateTime> _requestTimestamps = Queue<DateTime>();
  final Map<String, Completer<void>> _activeRequests = {};

  // Request queue
  final Queue<_QueuedRequest> _requestQueue = Queue<_QueuedRequest>();
  Timer? _queueTimer;
  bool _isProcessingQueue = false;

  // Initialize rate limit tracking
  void _cleanOldTimestamps() {
    final now = DateTime.now();
    while (_requestTimestamps.isNotEmpty &&
        now.difference(_requestTimestamps.first) > _timeWindow) {
      _requestTimestamps.removeFirst();
    }
  }

  // Check if we can make new request
  bool _canMakeRequest() {
    _cleanOldTimestamps();
    return _requestTimestamps.length < _maxRequestsPerMinute;
  }

  // Track new request
  void _trackRequest() {
    _requestTimestamps.addLast(DateTime.now());
  }

  // Request handling with rate limiting and cancellation
  Future<T> executeRequest<T>({
    required String requestId,
    required Future<T> Function() requestFn,
    CancellationToken? cancellationToken,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_activeRequests.containsKey(requestId)) {
      throw const RequestAlreadyInProgressException();
    }

    final completer = Completer<T>();
    _activeRequests[requestId] = Completer<void>();

    try {
      if (!_canMakeRequest()) {
        // Queue the request if we hit rate limit
        final queuedRequest = _QueuedRequest(
          id: requestId,
          execute: () => requestFn(),
          completer: completer,
          cancellationToken: cancellationToken,
        );
        _requestQueue.add(queuedRequest);
        _startQueueProcessing();

        if (kDebugMode) {
          print('🕒 Request queued: $requestId');
        }
      } else {
        // Execute request immediately if within rate limit
        _trackRequest();

        if (kDebugMode) {
          print('🚀 Executing request: $requestId');
        }

        T result;
        if (cancellationToken != null) {
          result = await _executeWithCancellation(
            requestFn,
            cancellationToken,
            timeout,
          );
        } else {
          result = await requestFn().timeout(timeout);
        }

        completer.complete(result);
      }

      return await completer.future;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Request failed: $requestId - $e');
      }
      completer.completeError(e);
      rethrow;
    } finally {
      _activeRequests.remove(requestId);
    }
  }

  // Execute request with cancellation support
  Future<T> _executeWithCancellation<T>(
    Future<T> Function() requestFn,
    CancellationToken cancellationToken,
    Duration timeout,
  ) async {
    if (cancellationToken.isCancelled) {
      throw const RequestCancelledException();
    }

    final resultCompleter = Completer<T>();

    // Listen for cancellation
    cancellationToken.addListener(() {
      if (!resultCompleter.isCompleted && cancellationToken.isCancelled) {
        resultCompleter.completeError(const RequestCancelledException());
      }
    });

    // Execute the request
    try {
      final result = await requestFn().timeout(timeout);
      if (!resultCompleter.isCompleted) {
        resultCompleter.complete(result);
      }
    } catch (e) {
      if (!resultCompleter.isCompleted) {
        resultCompleter.completeError(e);
      }
    }

    return resultCompleter.future;
  }

  // Process queued requests
  void _startQueueProcessing() {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    _queueTimer?.cancel();
    _queueTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _processNextRequest(),
    );
  }

  Future<void> _processNextRequest() async {
    if (_requestQueue.isEmpty) {
      _queueTimer?.cancel();
      _isProcessingQueue = false;
      return;
    }

    if (!_canMakeRequest()) return;

    final request = _requestQueue.removeFirst();

    if (request.cancellationToken?.isCancelled ?? false) {
      request.completer.completeError(const RequestCancelledException());
      return;
    }

    try {
      _trackRequest();

      if (kDebugMode) {
        print('🔄 Processing queued request: ${request.id}');
      }

      final result = await request.execute();
      request.completer.complete(result);
    } catch (e) {
      request.completer.completeError(e);
    }
  }

  // Cancel specific request
  void cancelRequest(String requestId) {
    final activeRequest = _activeRequests[requestId];
    if (activeRequest != null && !activeRequest.isCompleted) {
      activeRequest.completeError(const RequestCancelledException());
      _activeRequests.remove(requestId);
    }

    // Also remove from queue if exists
    _requestQueue.removeWhere((request) {
      if (request.id == requestId) {
        request.completer.completeError(const RequestCancelledException());
        return true;
      }
      return false;
    });
  }

  // Cancel all requests
  void cancelAllRequests() {
    for (final request in _activeRequests.values) {
      if (!request.isCompleted) {
        request.completeError(const RequestCancelledException());
      }
    }
    _activeRequests.clear();
    _requestQueue.clear();
    _queueTimer?.cancel();
    _isProcessingQueue = false;
  }

  // Check if request is active
  bool isRequestActive(String requestId) =>
      _activeRequests.containsKey(requestId);

  // Cleanup resources
  void dispose() {
    cancelAllRequests();
    _requestTimestamps.clear();
    _queueTimer?.cancel();
  }
}

// Request queue item
class _QueuedRequest<T> {
  final String id;
  final Future<T> Function() execute;
  final Completer<T> completer;
  final CancellationToken? cancellationToken;

  _QueuedRequest({
    required this.id,
    required this.execute,
    required this.completer,
    this.cancellationToken,
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
