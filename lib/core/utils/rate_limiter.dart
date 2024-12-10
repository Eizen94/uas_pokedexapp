// lib/core/utils/rate_limiter.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../constants/api_paths.dart';

/// Enhanced rate limiter with precise rate control and resource management
class RateLimiter {
  // Singleton instance with thread safety
  static final RateLimiter _instance = RateLimiter._internal();
  factory RateLimiter() => _instance;
  RateLimiter._internal();

  // Configuration management
  final Map<String, _RateLimitConfig> _configs = {};
  final Map<String, Queue<DateTime>> _requestTimestamps = {};
  final Map<String, Queue<_QueuedOperation>> _operationQueues = {};
  final Map<String, Timer> _queueProcessors = {};
  final Map<String, bool> _isProcessingQueue = {};

  // Thread safety
  final _lock = Lock();
  bool _disposed = false;

  /// Initialize endpoint with configuration
  Future<void> initializeEndpoint(
    String endpoint, {
    int requestsPerMinute = ApiPaths.publicApiLimit,
    Duration timeWindow = const Duration(minutes: 1),
    Duration minimumDelay = const Duration(milliseconds: 100),
  }) async {
    await _lock.synchronized(() async {
      _configs[endpoint] = _RateLimitConfig(
        requestsPerMinute: requestsPerMinute,
        timeWindow: timeWindow,
        minimumDelay: minimumDelay,
      );
      _requestTimestamps[endpoint] = Queue<DateTime>();
      _operationQueues[endpoint] = Queue<_QueuedOperation>();
      _isProcessingQueue[endpoint] = false;
    });
  }

  /// Check if request can be executed
  Future<bool> checkLimit(String endpoint) async {
    _ensureEndpointInitialized(endpoint);

    return await _lock.synchronized(() async {
      final timestamps = _requestTimestamps[endpoint]!;
      final config = _configs[endpoint]!;
      final now = DateTime.now();

      // Clean old timestamps
      while (timestamps.isNotEmpty &&
          now.difference(timestamps.first) > config.timeWindow) {
        timestamps.removeFirst();
      }

      // Check rate limit
      if (timestamps.isEmpty) return true;

      // Check minimum delay between requests
      if (now.difference(timestamps.last) < config.minimumDelay) return false;

      return timestamps.length < config.requestsPerMinute;
    });
  }

  /// Track request for rate limiting
  Future<void> trackRequest(String endpoint) async {
    await _lock.synchronized(() async {
      _requestTimestamps[endpoint]?.addLast(DateTime.now());
    });
  }

  /// Get remaining requests for endpoint
  Future<int> getRemainingRequests(String endpoint) async {
    _ensureEndpointInitialized(endpoint);

    return await _lock.synchronized(() async {
      final config = _configs[endpoint]!;
      final timestamps = _requestTimestamps[endpoint]!;
      return config.requestsPerMinute - timestamps.length;
    });
  }

  /// Get estimated wait time for next request
  Future<Duration> getEstimatedWaitTime(String endpoint) async {
    _ensureEndpointInitialized(endpoint);

    return await _lock.synchronized(() async {
      final timestamps = _requestTimestamps[endpoint]!;
      if (timestamps.isEmpty) return Duration.zero;

      final config = _configs[endpoint]!;
      final now = DateTime.now();
      final oldestTimestamp = timestamps.first;
      final timeWindowEnd = oldestTimestamp.add(config.timeWindow);

      return now.isAfter(timeWindowEnd)
          ? Duration.zero
          : timeWindowEnd.difference(now);
    });
  }

  /// Queue operation for later execution
  Future<T> queueOperation<T>(
    String endpoint,
    Future<T> Function() operation,
  ) async {
    _ensureEndpointInitialized(endpoint);

    final completer = Completer<T>();
    final queuedOp = _QueuedOperation(
      operation: operation,
      completer: completer,
    );

    await _lock.synchronized(() async {
      _operationQueues[endpoint]!.addLast(queuedOp);
      _startQueueProcessor(endpoint);
    });

    return completer.future;
  }

  /// Process queued operations
  Future<void> _processQueue(String endpoint) async {
    if (_disposed) return;

    await _lock.synchronized(() async {
      final queue = _operationQueues[endpoint]!;
      if (queue.isEmpty) {
        _stopQueueProcessor(endpoint);
        return;
      }

      if (!await checkLimit(endpoint)) return;

      final operation = queue.removeFirst();
      try {
        final result = await operation.operation();
        await trackRequest(endpoint);
        operation.completer.complete(result);
      } catch (e) {
        operation.completer.completeError(e);
      }

      if (queue.isEmpty) {
        _stopQueueProcessor(endpoint);
      }
    });
  }

  /// Start queue processor
  void _startQueueProcessor(String endpoint) {
    if (_isProcessingQueue[endpoint] ?? false) return;

    _isProcessingQueue[endpoint] = true;
    _queueProcessors[endpoint]?.cancel();

    _queueProcessors[endpoint] = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _processQueue(endpoint),
    );
  }

  /// Stop queue processor
  void _stopQueueProcessor(String endpoint) {
    _queueProcessors[endpoint]?.cancel();
    _queueProcessors.remove(endpoint);
    _isProcessingQueue[endpoint] = false;
  }

  /// Ensure endpoint is initialized
  void _ensureEndpointInitialized(String endpoint) {
    if (!_configs.containsKey(endpoint)) {
      if (kDebugMode) {
        print('Initializing rate limiter for endpoint: $endpoint');
      }
      initializeEndpoint(endpoint);
    }
  }

  /// Reset all limits
  Future<void> reset() async {
    await _lock.synchronized(() async {
      for (final endpoint in _configs.keys) {
        _requestTimestamps[endpoint]?.clear();
        _operationQueues[endpoint]?.clear();
        _stopQueueProcessor(endpoint);
      }
    });
  }

  /// Resource cleanup
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;
    await reset();
    _configs.clear();
    _requestTimestamps.clear();
    _operationQueues.clear();
    for (final timer in _queueProcessors.values) {
      timer.cancel();
    }
    _queueProcessors.clear();
    _isProcessingQueue.clear();
  }
}

/// Rate limit configuration
class _RateLimitConfig {
  final int requestsPerMinute;
  final Duration timeWindow;
  final Duration minimumDelay;

  _RateLimitConfig({
    required this.requestsPerMinute,
    required this.timeWindow,
    required this.minimumDelay,
  });
}

/// Queued operation with completion handling
class _QueuedOperation<T> {
  final Future<T> Function() operation;
  final Completer<T> completer;

  _QueuedOperation({
    required this.operation,
    required this.completer,
  });
}

/// Thread-safe lock implementation
class Lock {
  Completer<void>? _completer;
  bool _locked = false;

  Future<T> synchronized<T>(Future<T> Function() operation) async {
    while (_locked) {
      _completer = Completer<void>();
      await _completer?.future;
    }

    _locked = true;
    try {
      return await operation();
    } finally {
      _locked = false;
      _completer?.complete();
    }
  }
}
