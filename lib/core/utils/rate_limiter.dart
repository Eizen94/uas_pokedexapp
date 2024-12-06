// lib/core/utils/rate_limiter.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:uas_pokedexapp/core/constants/api_paths.dart';

class RateLimiter {
  // Singleton instance
  static final RateLimiter _instance = RateLimiter._internal();
  factory RateLimiter() => _instance;
  RateLimiter._internal();

  // Configuration
  final Map<String, _RateLimitConfig> _configs = {};
  final Map<String, Queue<DateTime>> _requestTimestamps = {};
  final Map<String, Queue<_QueuedOperation>> _operationQueues = {};
  final Map<String, Timer> _queueProcessors = {};
  final Map<String, bool> _isProcessingQueue = {};

  // Initialize configuration for an endpoint
  void initializeEndpoint(
    String endpoint, {
    int requestsPerMinute = ApiPaths.publicApiLimit,
    Duration timeWindow = const Duration(minutes: 1),
    Duration minimumDelay = const Duration(milliseconds: 100),
  }) {
    _configs[endpoint] = _RateLimitConfig(
      requestsPerMinute: requestsPerMinute,
      timeWindow: timeWindow,
      minimumDelay: minimumDelay,
    );
    _requestTimestamps[endpoint] = Queue<DateTime>();
    _operationQueues[endpoint] = Queue<_QueuedOperation>();
    _isProcessingQueue[endpoint] = false;
  }

  // Execute rate-limited operation
  Future<T> executeRateLimited<T>(
    String endpoint,
    Future<T> Function() operation,
  ) async {
    _ensureEndpointInitialized(endpoint);

    if (await _canExecuteNow(endpoint)) {
      return await _executeOperation(endpoint, operation);
    } else {
      return await _queueOperation(endpoint, operation);
    }
  }

  // Ensure endpoint is initialized with default config
  void _ensureEndpointInitialized(String endpoint) {
    if (!_configs.containsKey(endpoint)) {
      if (kDebugMode) {
        print('Initializing rate limiter for endpoint: $endpoint');
      }
      initializeEndpoint(endpoint);
    }
  }

  // Check if operation can be executed now
  Future<bool> _canExecuteNow(String endpoint) async {
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
  }

  // Execute operation with rate limiting
  Future<T> _executeOperation<T>(
    String endpoint,
    Future<T> Function() operation,
  ) async {
    try {
      _trackRequest(endpoint);
      if (kDebugMode) {
        print('Executing operation for endpoint: $endpoint');
      }
      return await operation();
    } catch (e) {
      if (kDebugMode) {
        print('Error executing operation for endpoint $endpoint: $e');
      }
      rethrow;
    }
  }

  // Track request timestamp
  void _trackRequest(String endpoint) {
    _requestTimestamps[endpoint]!.addLast(DateTime.now());
  }

  // Queue operation for later execution
  Future<T> _queueOperation<T>(
    String endpoint,
    Future<T> Function() operation,
  ) {
    final completer = Completer<T>();
    final queuedOp = _QueuedOperation(
      operation: operation,
      completer: completer,
    );

    _operationQueues[endpoint]!.addLast(queuedOp);
    _startQueueProcessor(endpoint);

    if (kDebugMode) {
      final queueLength = _operationQueues[endpoint]!.length;
      print(
          'Operation queued for endpoint $endpoint. Queue length: $queueLength');
    }

    return completer.future;
  }

  // Start queue processor if not already running
  void _startQueueProcessor(String endpoint) {
    if (_isProcessingQueue[endpoint]!) return;

    _isProcessingQueue[endpoint] = true;
    _queueProcessors[endpoint]?.cancel();

    _queueProcessors[endpoint] = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _processQueue(endpoint),
    );
  }

  // Process queued operations
  Future<void> _processQueue(String endpoint) async {
    final queue = _operationQueues[endpoint]!;
    if (queue.isEmpty) {
      _stopQueueProcessor(endpoint);
      return;
    }

    if (!await _canExecuteNow(endpoint)) return;

    final operation = queue.removeFirst();
    try {
      final result = await _executeOperation(
        endpoint,
        operation.operation,
      );
      operation.completer.complete(result);
    } catch (e) {
      operation.completer.completeError(e);
    }

    if (queue.isEmpty) {
      _stopQueueProcessor(endpoint);
    }
  }

  // Stop queue processor
  void _stopQueueProcessor(String endpoint) {
    _queueProcessors[endpoint]?.cancel();
    _queueProcessors.remove(endpoint);
    _isProcessingQueue[endpoint] = false;
  }

  // Get current queue length for endpoint
  int getQueueLength(String endpoint) {
    _ensureEndpointInitialized(endpoint);
    return _operationQueues[endpoint]!.length;
  }

  // Get remaining requests for endpoint
  int getRemainingRequests(String endpoint) {
    _ensureEndpointInitialized(endpoint);
    final config = _configs[endpoint]!;
    final timestamps = _requestTimestamps[endpoint]!;
    return config.requestsPerMinute - timestamps.length;
  }

  // Clear all queues and timestamps
  void reset() {
    for (final endpoint in _configs.keys) {
      _requestTimestamps[endpoint]?.clear();
      _operationQueues[endpoint]?.clear();
      _stopQueueProcessor(endpoint);
    }
  }

  // Check if endpoint is rate limited
  bool isRateLimited(String endpoint) {
    _ensureEndpointInitialized(endpoint);
    return getRemainingRequests(endpoint) <= 0;
  }

  // Get estimated wait time for next available slot
  Duration getEstimatedWaitTime(String endpoint) {
    _ensureEndpointInitialized(endpoint);
    final timestamps = _requestTimestamps[endpoint]!;
    if (timestamps.isEmpty) return Duration.zero;

    final config = _configs[endpoint]!;
    final now = DateTime.now();
    final oldestTimestamp = timestamps.first;
    final timeWindowEnd = oldestTimestamp.add(config.timeWindow);

    if (now.isAfter(timeWindowEnd)) return Duration.zero;
    return timeWindowEnd.difference(now);
  }

  // Cleanup resources
  void dispose() {
    for (final timer in _queueProcessors.values) {
      timer.cancel();
    }
    _queueProcessors.clear();
    _operationQueues.clear();
    _requestTimestamps.clear();
    _configs.clear();
    _isProcessingQueue.clear();
  }
}

// Configuration for rate limiting
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

// Queued operation
class _QueuedOperation<T> {
  final Future<T> Function() operation;
  final Completer<T> completer;

  _QueuedOperation({
    required this.operation,
    required this.completer,
  });
}
