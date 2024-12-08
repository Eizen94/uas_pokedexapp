// lib/core/utils/queue_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Manages queue operations with size limits, prioritization, and batch processing.
/// Provides thread-safe operations and memory management.
class QueueManager<T> {
  // Singleton pattern
  static final Map<Type, QueueManager> _instances = {};
  factory QueueManager() {
    return _instances.putIfAbsent(T, () => QueueManager._internal());
  }
  QueueManager._internal();

  // Core queue implementation
  final Queue<T> _queue = Queue<T>();
  final _lock = Lock();

  // Queue configuration
  final int _maxSize;
  final Duration _timeout;
  final int _maxBatchSize;

  // Batch processing
  final _batchProcessingController = StreamController<List<T>>.broadcast();
  Timer? _batchTimer;
  List<T> _currentBatch = [];

  // Queue metrics
  int _totalProcessed = 0;
  int _totalErrors = 0;
  DateTime? _lastProcessedTime;

  // Constants
  static const int defaultMaxSize = 1000;
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const int defaultBatchSize = 50;
  static const Duration defaultBatchDelay = Duration(milliseconds: 100);

  QueueManager({
    int maxSize = defaultMaxSize,
    Duration timeout = defaultTimeout,
    int maxBatchSize = defaultBatchSize,
  })  : _maxSize = maxSize,
        _timeout = timeout,
        _maxBatchSize = maxBatchSize;

  // Public getters
  bool get isEmpty => _queue.isEmpty;
  bool get isNotEmpty => _queue.isNotEmpty;
  int get length => _queue.length;
  int get totalProcessed => _totalProcessed;
  int get totalErrors => _totalErrors;
  DateTime? get lastProcessedTime => _lastProcessedTime;
  Stream<List<T>> get batchProcessStream => _batchProcessingController.stream;

  /// Add item to queue with overflow protection
  Future<void> enqueue(T item) async {
    await _lock.synchronized(() async {
      if (_queue.length >= _maxSize) {
        throw QueueOverflowException(
            'Queue size exceeded limit of $_maxSize items');
      }
      _queue.add(item);
      _checkBatchProcessing();
      return;
    });
  }

  /// Add multiple items to queue
  Future<void> enqueueAll(Iterable<T> items) async {
    await _lock.synchronized(() async {
      if (_queue.length + items.length > _maxSize) {
        throw QueueOverflowException(
            'Adding ${items.length} items would exceed queue limit of $_maxSize');
      }
      _queue.addAll(items);
      _checkBatchProcessing();
      return;
    });
  }

  /// Remove and return item from queue
  Future<T> dequeue() async {
    return await _lock.synchronized(() async {
      if (_queue.isEmpty) {
        throw QueueEmptyException('Queue is empty');
      }
      final item = _queue.removeFirst();
      _lastProcessedTime = DateTime.now();
      _totalProcessed++;
      return item;
    });
  }

  /// Try to dequeue with timeout
  Future<T?> tryDequeue({Duration? timeout}) async {
    try {
      return await _lock.synchronized(() async {
        if (_queue.isEmpty) return null;
        return await dequeue().timeout(timeout ?? _timeout);
      });
    } on TimeoutException {
      return null;
    }
  }

  /// Remove all items from queue
  Future<void> clear() async {
    await _lock.synchronized(() async {
      _queue.clear();
      _currentBatch.clear();
      _batchTimer?.cancel();
      return;
    });
  }

  /// Get items without removing them
  Future<List<T>> peek(int count) async {
    return await _lock.synchronized(() async {
      if (_queue.isEmpty) return [];
      return _queue.take(count).toList();
    });
  }

  /// Start batch processing
  void startBatchProcessing() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(defaultBatchDelay, (_) {
      _processBatch();
    });
  }

  /// Stop batch processing
  void stopBatchProcessing() {
    _batchTimer?.cancel();
    _batchTimer = null;
    _processPendingBatch();
  }

  /// Process current batch if available
  void _checkBatchProcessing() {
    if (_currentBatch.length >= _maxBatchSize) {
      _processPendingBatch();
    }
  }

  /// Process items in batches
  Future<void> _processBatch() async {
    await _lock.synchronized(() async {
      if (_queue.isEmpty) return;

      final itemsToProcess = _queue.take(_maxBatchSize).toList();
      if (itemsToProcess.isEmpty) return;

      _currentBatch.addAll(itemsToProcess);
      for (var _ in itemsToProcess) {
        _queue.removeFirst();
      }

      _processPendingBatch();
      return;
    });
  }

  /// Process any pending batch items
  void _processPendingBatch() {
    if (_currentBatch.isEmpty) return;

    if (!_batchProcessingController.isClosed) {
      _batchProcessingController.add(List.from(_currentBatch));
    }
    _currentBatch.clear();
  }

  /// Register error for metrics
  void registerError() {
    _totalErrors++;
  }

  /// Reset metrics
  void resetMetrics() {
    _totalProcessed = 0;
    _totalErrors = 0;
    _lastProcessedTime = null;
  }

  /// Cleanup resources
  Future<void> dispose() async {
    _batchTimer?.cancel();
    await _batchProcessingController.close();
    await clear();
  }
}

/// Lock implementation for thread safety
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

/// Custom exceptions
class QueueOverflowException implements Exception {
  final String message;
  QueueOverflowException(this.message);

  @override
  String toString() => 'QueueOverflowException: $message';
}

class QueueEmptyException implements Exception {
  final String message;
  QueueEmptyException(this.message);

  @override
  String toString() => 'QueueEmptyException: $message';
}
