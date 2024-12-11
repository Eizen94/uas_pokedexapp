// lib/core/utils/queue_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import './cancellation_token.dart';
import './monitoring_manager.dart';
import './request_manager.dart';

/// Manages queue operations with size limits, prioritization, and batch processing
class QueueManager<T> {
  // Singleton pattern with type safety
  static final Map<Type, QueueManager> _instances = {};

  factory QueueManager() {
    return _instances.putIfAbsent(
      T,
      () => QueueManager<T>._internal(
        maxSize: defaultMaxSize,
        timeout: defaultTimeout,
        maxBatchSize: defaultBatchSize,
      ),
    ) as QueueManager<T>;
  }

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
  final List<T> _currentBatch = [];

  // Queue metrics
  int _totalProcessed = 0;
  int _totalErrors = 0;
  DateTime? _lastProcessedTime;
  bool _isDisposed = false;

  // Constants
  static const int defaultMaxSize = 1000;
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const int defaultBatchSize = 50;
  static const Duration defaultBatchDelay = Duration(milliseconds: 100);

  QueueManager._internal({
    required int maxSize,
    required Duration timeout,
    required int maxBatchSize,
  })  : _maxSize = maxSize,
        _timeout = timeout,
        _maxBatchSize = maxBatchSize {
    if (kDebugMode) {
      print(
          '🔧 Initializing QueueManager<$T> with maxSize: $maxSize, batchSize: $maxBatchSize');
    }
  }

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
    if (_isDisposed) {
      throw StateError('QueueManager has been disposed');
    }

    await _lock.synchronized(() async {
      if (_queue.length >= _maxSize) {
        if (kDebugMode) {
          print(
              '❌ Queue overflow: Cannot add item, queue size $_maxSize exceeded');
        }
        throw QueueOverflowException(
          'Queue size exceeded limit of $_maxSize items',
        );
      }

      _queue.add(item);

      if (kDebugMode) {
        print('✅ Item added to queue: ${_queue.length} items total');
      }

      _checkBatchProcessing();
    });
  }

  /// Add multiple items to queue
  Future<void> enqueueAll(Iterable<T> items) async {
    if (_isDisposed) {
      throw StateError('QueueManager has been disposed');
    }

    await _lock.synchronized(() async {
      if (_queue.length + items.length > _maxSize) {
        if (kDebugMode) {
          print(
              '❌ Queue overflow: Cannot add ${items.length} items, would exceed limit $_maxSize');
        }
        throw QueueOverflowException(
          'Adding ${items.length} items would exceed queue limit of $_maxSize',
        );
      }

      _queue.addAll(items);

      if (kDebugMode) {
        print('✅ Added ${items.length} items to queue: ${_queue.length} total');
      }

      _checkBatchProcessing();
    });
  }

  /// Remove and return item from queue
  Future<T> dequeue() async {
    if (_isDisposed) {
      throw StateError('QueueManager has been disposed');
    }

    return await _lock.synchronized(() async {
      if (_queue.isEmpty) {
        if (kDebugMode) {
          print('⚠️ Attempted to dequeue from empty queue');
        }
        throw QueueEmptyException('Queue is empty');
      }

      final item = _queue.removeFirst();
      _lastProcessedTime = DateTime.now();
      _totalProcessed++;

      if (kDebugMode) {
        print('✅ Item dequeued: $_totalProcessed total processed');
      }

      return item;
    });
  }

  /// Try to dequeue with timeout
  Future<T?> tryDequeue({Duration? timeout}) async {
    if (_isDisposed) {
      throw StateError('QueueManager has been disposed');
    }

    try {
      return await _lock.synchronized(() async {
        if (_queue.isEmpty) {
          if (kDebugMode) {
            print('ℹ️ Queue empty during tryDequeue');
          }
          return null;
        }
        return await dequeue().timeout(timeout ?? _timeout);
      });
    } on TimeoutException {
      if (kDebugMode) {
        print('⚠️ Dequeue operation timed out');
      }
      return null;
    }
  }

  /// Process current batch if available
  void _checkBatchProcessing() {
    if (_currentBatch.length >= _maxBatchSize) {
      if (kDebugMode) {
        print('📦 Batch size threshold reached: processing current batch');
      }
      _processPendingBatch();
    }
  }

  /// Process batches
  Future<void> _processBatch() async {
    await _lock.synchronized(() async {
      if (_queue.isEmpty) return;

      final itemsToProcess = _queue.take(_maxBatchSize).toList();
      if (itemsToProcess.isEmpty) return;

      if (kDebugMode) {
        print('📦 Processing batch of ${itemsToProcess.length} items');
      }

      _currentBatch.addAll(itemsToProcess);
      for (var _ in itemsToProcess) {
        _queue.removeFirst();
      }

      _processPendingBatch();
    });
  }

  /// Process pending batch items
  void _processPendingBatch() {
    if (_currentBatch.isEmpty || _isDisposed) return;

    if (!_batchProcessingController.isClosed) {
      if (kDebugMode) {
        print('📤 Sending batch of ${_currentBatch.length} items to stream');
      }
      _batchProcessingController.add(List.from(_currentBatch));
    }
    _currentBatch.clear();
  }

  /// Register error for metrics
  void registerError() {
    if (!_isDisposed) {
      _totalErrors++;
      if (kDebugMode) {
        print('⚠️ Queue error registered: Total errors: $_totalErrors');
      }
    }
  }

  /// Reset metrics
  void resetMetrics() {
    if (!_isDisposed) {
      if (kDebugMode) {
        print('🔄 Resetting queue metrics');
      }
      _totalProcessed = 0;
      _totalErrors = 0;
      _lastProcessedTime = null;
    }
  }

  /// Clean resource disposal
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _batchTimer?.cancel();
    await _batchProcessingController.close();
    await clear();

    if (kDebugMode) {
      print('🧹 QueueManager disposed');
    }
  }

  /// Clear the queue
  Future<void> clear() async {
    await _lock.synchronized(() async {
      _queue.clear();
      _currentBatch.clear();
      _batchTimer?.cancel();
    });
  }
}

/// Custom exceptions for proper error handling
class QueueOverflowException implements Exception {
  final String message;

  const QueueOverflowException(this.message);

  @override
  String toString() => 'QueueOverflowException: $message';
}

class QueueEmptyException implements Exception {
  final String message;

  const QueueEmptyException(this.message);

  @override
  String toString() => 'QueueEmptyException: $message';
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
