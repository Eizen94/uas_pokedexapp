// lib/core/utils/rate_limiter.dart

// Dart imports
import 'dart:async';
import 'dart:collection';

// Package imports
import 'package:flutter/foundation.dart';

// Local imports
import '../constants/api_paths.dart';
import 'monitoring_manager.dart';

/// Enhanced rate limiter with precise rate control and resource management.
/// Provides thread-safe rate limiting with proper cleanup and monitoring.
class RateLimiter {
  // Singleton implementation
  static final RateLimiter _instance = RateLimiter._internal();
  static final _lock = Object();

  // Configuration management
  final Map<String, RateLimitConfig> _configs = {};
  final Map<String, Queue<DateTime>> _requestTimestamps = {};
  final Map<String, Queue<QueuedOperation>> _operationQueues = {};
  final Map<String, Timer> _queueProcessors = {};
  final Map<String, bool> _isProcessingQueue = {};

  // Monitoring
  final StreamController<RateLimitEvent> _eventController =
      StreamController<RateLimitEvent>.broadcast();
  int _totalThrottled = 0;
  bool _disposed = false;

  // Constants
  static const Duration _defaultWindow = Duration(minutes: 1);
  static const Duration _defaultMinDelay = Duration(milliseconds: 100);
  static const Duration _queueProcessInterval = Duration(milliseconds: 100);

  // Private constructor
  RateLimiter._internal();

  // Factory constructor
  factory RateLimiter() => _instance;

  /// Initialize endpoint with rate limit configuration
  Future<void> initializeEndpoint(
    String endpoint, {
    int requestsPerMinute = ApiPaths.publicApiLimit,
    Duration timeWindow = const Duration(minutes: 1),
    Duration minimumDelay = const Duration(milliseconds: 100),
  }) async {
    _throwIfDisposed();

    await synchronized(_lock, () async {
      _configs[endpoint] = RateLimitConfig(
        requestsPerMinute: requestsPerMinute,
        timeWindow: timeWindow,
        minimumDelay: minimumDelay,
      );
      _requestTimestamps[endpoint] = Queue<DateTime>();
      _operationQueues[endpoint] = Queue<QueuedOperation>();
      _isProcessingQueue[endpoint] = false;

      _notifyEvent(
        RateLimitEventType.endpointInitialized,
        endpoint: endpoint,
        config: _configs[endpoint],
      );
    });
  }

  /// Check if request can be executed
  Future<bool> checkLimit(String endpoint) async {
    _throwIfDisposed();
    _ensureEndpointInitialized(endpoint);

    return await synchronized(_lock, () async {
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

      // Check minimum delay
      if (now.difference(timestamps.last) < config.minimumDelay) {
        _totalThrottled++;
        _notifyEvent(
          RateLimitEventType.requestThrottled,
          endpoint: endpoint,
        );
        return false;
      }

      final withinLimit = timestamps.length < config.requestsPerMinute;
      if (!withinLimit) {
        _totalThrottled++;
        _notifyEvent(
          RateLimitEventType.limitExceeded,
          endpoint: endpoint,
        );
      }
      return withinLimit;
    });
  }

  /// Track request for rate limiting
  Future<void> trackRequest(String endpoint) async {
    _throwIfDisposed();
    _ensureEndpointInitialized(endpoint);

    await synchronized(_lock, () async {
      _requestTimestamps[endpoint]?.addLast(DateTime.now());
      _notifyEvent(
        RateLimitEventType.requestTracked,
        endpoint: endpoint,
      );
    });
  }

  /// Get remaining requests for endpoint
  Future<int> getRemainingRequests(String endpoint) async {
    _throwIfDisposed();
    _ensureEndpointInitialized(endpoint);

    return await synchronized(_lock, () async {
      final config = _configs[endpoint]!;
      final timestamps = _requestTimestamps[endpoint]!;
      return config.requestsPerMinute - timestamps.length;
    });
  }

  /// Get estimated wait time for next request
  Future<Duration> getEstimatedWaitTime(String endpoint) async {
    _throwIfDisposed();
    _ensureEndpointInitialized(endpoint);

    return await synchronized(_lock, () async {
      final timestamps = _requestTimestamps[endpoint]!;
      if (timestamps.isEmpty) return Duration.zero;

      final config = _configs[endpoint]!;
      final now = DateTime.now();
      final oldestTimestamp = timestamps.first;
      final timeWindowEnd = oldestTimestamp.add(config.timeWindow);

      if (now.isAfter(timeWindowEnd)) return Duration.zero;

      final waitTime = timeWindowEnd.difference(now);
      _notifyEvent(
        RateLimitEventType.waitTimeCalculated,
        endpoint: endpoint,
        duration: waitTime,
      );

      return waitTime;
    });
  }

  /// Queue operation for later execution
  Future<T> queueOperation<T>(
    String endpoint,
    Future<T> Function() operation,
  ) async {
    _throwIfDisposed();
    _ensureEndpointInitialized(endpoint);

    final completer = Completer<T>();
    final queuedOp = QueuedOperation(
      operation: operation,
      completer: completer,
      timestamp: DateTime.now(),
    );

    await synchronized(_lock, () async {
      _operationQueues[endpoint]!.addLast(queuedOp);
      _startQueueProcessor(endpoint);

      _notifyEvent(
        RateLimitEventType.operationQueued,
        endpoint: endpoint,
      );
    });

    return completer.future;
  }

  /// Process queued operations
  Future<void> _processQueue(String endpoint) async {
    if (_disposed) return;

    await synchronized(_lock, () async {
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

        _notifyEvent(
          RateLimitEventType.operationProcessed,
          endpoint: endpoint,
        );
      } catch (e) {
        operation.completer.completeError(e);
        _notifyEvent(
          RateLimitEventType.operationFailed,
          endpoint: endpoint,
          error: e,
        );
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
      _queueProcessInterval,
      (_) => _processQueue(endpoint),
    );

    _notifyEvent(
      RateLimitEventType.queueProcessingStarted,
      endpoint: endpoint,
    );
  }

  /// Stop queue processor
  void _stopQueueProcessor(String endpoint) {
    _queueProcessors[endpoint]?.cancel();
    _queueProcessors.remove(endpoint);
    _isProcessingQueue[endpoint] = false;

    _notifyEvent(
      RateLimitEventType.queueProcessingStopped,
      endpoint: endpoint,
    );
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

  /// Notify rate limit event
  void _notifyEvent(
    RateLimitEventType type, {
    String? endpoint,
    RateLimitConfig? config,
    Duration? duration,
    Object? error,
  }) {
    if (!_eventController.isClosed && !_disposed) {
      _eventController.add(RateLimitEvent(
        type: type,
        endpoint: endpoint,
        config: config,
        duration: duration,
        error: error,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Reset all limits
  Future<void> reset() async {
    _throwIfDisposed();

    await synchronized(_lock, () async {
      for (final endpoint in _configs.keys) {
        _requestTimestamps[endpoint]?.clear();
        _operationQueues[endpoint]?.clear();
        _stopQueueProcessor(endpoint);
      }
      _totalThrottled = 0;

      _notifyEvent(RateLimitEventType.reset);
    });
  }

  /// Get monitoring stream
  Stream<RateLimitEvent> get events => _eventController.stream;

  /// Get total throttled requests
  int get totalThrottled => _totalThrottled;

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

    await _eventController.close();

    if (kDebugMode) {
      print('🧹 RateLimiter disposed');
    }
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError('RateLimiter has been disposed');
    }
  }
}

/// Rate limit configuration
class RateLimitConfig {
  final int requestsPerMinute;
  final Duration timeWindow;
  final Duration minimumDelay;

  const RateLimitConfig({
    required this.requestsPerMinute,
    required this.timeWindow,
    required this.minimumDelay,
  });

  @override
  String toString() => 'RateLimitConfig('
      'rpm: $requestsPerMinute, '
      'window: ${timeWindow.inSeconds}s, '
      'delay: ${minimumDelay.inMilliseconds}ms)';
}

/// Queued operation with completion handling
class QueuedOperation<T> {
  final Future<T> Function() operation;
  final Completer<T> completer;
  final DateTime timestamp;

  QueuedOperation({
    required this.operation,
    required this.completer,
    required this.timestamp,
  });
}

/// Rate limit event types
enum RateLimitEventType {
  endpointInitialized,
  requestThrottled,
  limitExceeded,
  requestTracked,
  waitTimeCalculated,
  operationQueued,
  operationProcessed,
  operationFailed,
  queueProcessingStarted,
  queueProcessingStopped,
  reset,
}

/// Rate limit event for monitoring
class RateLimitEvent {
  final RateLimitEventType type;
  final String? endpoint;
  final RateLimitConfig? config;
  final Duration? duration;
  final Object? error;
  final DateTime timestamp;

  RateLimitEvent({
    required this.type,
    this.endpoint,
    this.config,
    this.duration,
    this.error,
    required this.timestamp,
  });

  @override
  String toString() => 'RateLimitEvent('
      'type: $type, '
      'endpoint: $endpoint, '
      'timestamp: $timestamp)';
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
