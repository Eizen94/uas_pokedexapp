// lib/core/utils/queue_manager.dart

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'cancellation_token.dart';
import 'monitoring_manager.dart';
import 'request_manager.dart';
import '../constants/api_paths.dart';

/// Enhanced queue manager with proper generic constraints and resource management.
/// Type T must be a non-nullable type to ensure type safety.
class QueueManager<T extends Object> {
  // Singleton pattern with type safety
  static final Map<Type, QueueManager> _instances = {};
  static final Object _lock = Object();

  // Core queue implementation with proper typing
  final Queue<QueueItem<T>> _queue = Queue<QueueItem<T>>();
  final Map<Priority, Queue<QueueItem<T>>> _priorityQueues = {
    Priority.high: Queue<QueueItem<T>>(),
    Priority.normal: Queue<QueueItem<T>>(),
    Priority.low: Queue<QueueItem<T>>(),
  };

  // Batch processing with proper typing
  final _batchProcessingController = StreamController<List<T>>.broadcast();
  Timer? _batchTimer;
  final List<T> _currentBatch = [];

  // Resource tracking
  int _totalProcessed = 0;
  int _totalErrors = 0;
  DateTime? _lastProcessedTime;
  final _activeTasks = <String, Completer<void>>{};
  final _processLock = Object();
  final StreamController<QueueEvent> _eventController =
      StreamController<QueueEvent>.broadcast();

  // State management
  bool _isProcessing = false;
  bool _isPaused = false;
  bool _isDisposed = false;

  // Configuration
  final int _maxSize;
  final Duration _timeout;
  final int _maxBatchSize;
  final Duration _batchDelay;
  final int _maxConcurrentTasks;

  // Constants
  static const int defaultMaxSize = 1000;
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const int defaultBatchSize = 50;
  static const Duration defaultBatchDelay = Duration(milliseconds: 100);
  static const int defaultMaxConcurrentTasks = 4;

  // Factory constructor with proper type constraints
  factory QueueManager({
    int? maxSize,
    Duration? timeout,
    int? maxBatchSize,
    Duration? batchDelay,
    int? maxConcurrentTasks,
  }) {
    return _instances.putIfAbsent(
      T,
      () => QueueManager<T>._internal(
        maxSize: maxSize ?? defaultMaxSize,
        timeout: timeout ?? defaultTimeout,
        maxBatchSize: maxBatchSize ?? defaultBatchSize,
        batchDelay: batchDelay ?? defaultBatchDelay,
        maxConcurrentTasks: maxConcurrentTasks ?? defaultMaxConcurrentTasks,
      ),
    ) as QueueManager<T>;
  }

  // Private constructor with initialization
  QueueManager._internal({
    required int maxSize,
    required Duration timeout,
    required int maxBatchSize,
    required Duration batchDelay,
    required int maxConcurrentTasks,
  })  : _maxSize = maxSize,
        _timeout = timeout,
        _maxBatchSize = maxBatchSize,
        _batchDelay = batchDelay,
        _maxConcurrentTasks = maxConcurrentTasks {
    if (kDebugMode) {
      print('🔧 Initializing QueueManager<$T>');
    }
  }

  // Public getters with proper type safety
  bool get isEmpty =>
      _queue.isEmpty && _priorityQueues.values.every((q) => q.isEmpty);
  bool get isNotEmpty => !isEmpty;
  int get length =>
      _queue.length +
      _priorityQueues.values.fold(0, (sum, q) => sum + q.length);
  int get totalProcessed => _totalProcessed;
  int get totalErrors => _totalErrors;
  DateTime? get lastProcessedTime => _lastProcessedTime;
  Stream<List<T>> get batchProcessStream => _batchProcessingController.stream;
  Stream<QueueEvent> get events => _eventController.stream;

  /// Add item to queue with proper type constraints
  Future<void> enqueue(
    T item, {
    Priority priority = Priority.normal,
    String? id,
    Duration? timeout,
    CancellationToken? cancellationToken,
  }) async {
    _throwIfDisposed();

    final queueItem = QueueItem<T>(
      item: item,
      priority: priority,
      id: id ?? _generateId(),
      addedTime: DateTime.now(),
      timeout: timeout ?? _timeout,
      cancellationToken: cancellationToken,
    );

    await synchronized(_lock, () async {
      _validateQueueSize();

      if (priority == Priority.normal) {
        _queue.add(queueItem);
      } else {
        _priorityQueues[priority]!.add(queueItem);
      }

      _notifyQueueEvent(QueueEventType.itemAdded, item: item);
      _startProcessingIfNeeded();
    });
  }

  /// Add multiple items with batch validation
  Future<void> enqueueAll(
    Iterable<T> items, {
    Priority priority = Priority.normal,
    Duration? timeout,
    CancellationToken? cancellationToken,
  }) async {
    _throwIfDisposed();

    await synchronized(_lock, () async {
      _validateQueueSizeForBatch(items.length);

      for (final item in items) {
        final queueItem = QueueItem<T>(
          item: item,
          priority: priority,
          id: _generateId(),
          addedTime: DateTime.now(),
          timeout: timeout ?? _timeout,
          cancellationToken: cancellationToken,
        );

        if (priority == Priority.normal) {
          _queue.add(queueItem);
        } else {
          _priorityQueues[priority]!.add(queueItem);
        }
      }

      _notifyQueueEvent(QueueEventType.batchAdded, count: items.length);
      _startProcessingIfNeeded();
    });
  }

  /// Remove and return next item with proper error handling
  Future<T> dequeue() async {
    _throwIfDisposed();

    return await synchronized(_lock, () async {
      final item = _getNextItem();
      if (item == null) {
        throw QueueEmptyException('Queue is empty');
      }

      _lastProcessedTime = DateTime.now();
      _totalProcessed++;

      _notifyQueueEvent(QueueEventType.itemProcessed, item: item.item);
      return item.item;
    });
  }

  /// Process items in queue with proper resource tracking
  Future<void> process(
    Future<void> Function(T item) processor, {
    CancellationToken? cancellationToken,
  }) async {
    _throwIfDisposed();

    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (!isEmpty && !_isPaused && !_isDisposed) {
        cancellationToken?.throwIfCancelled();

        final batch = await _getBatch();
        await _processBatch(batch, processor);
      }
    } catch (e) {
      _handleProcessingError(e);
    } finally {
      _isProcessing = false;
    }
  }

  /// Pause queue processing
  void pause() {
    _isPaused = true;
    _notifyQueueEvent(QueueEventType.paused);
  }

  /// Resume queue processing
  void resume() {
    _isPaused = false;
    _notifyQueueEvent(QueueEventType.resumed);
    _startProcessingIfNeeded();
  }

  /// Clear the queue with proper cleanup
  Future<void> clear() async {
    await synchronized(_lock, () async {
      _queue.clear();
      _priorityQueues.values.forEach((q) => q.clear());
      _currentBatch.clear();
      _batchTimer?.cancel();

      _notifyQueueEvent(QueueEventType.cleared);
    });
  }

  /// Get next batch with proper timeout handling
  Future<List<QueueItem<T>>> _getBatch() async {
    final batch = <QueueItem<T>>[];
    final now = DateTime.now();

    // Process high priority items first
    while (batch.length < _maxBatchSize &&
        _priorityQueues[Priority.high]!.isNotEmpty) {
      final item = _priorityQueues[Priority.high]!.removeFirst();
      if (!_isItemExpired(item, now)) {
        batch.add(item);
      }
    }

    // Then normal priority
    while (batch.length < _maxBatchSize && _queue.isNotEmpty) {
      final item = _queue.removeFirst();
      if (!_isItemExpired(item, now)) {
        batch.add(item);
      }
    }

    // Finally low priority
    while (batch.length < _maxBatchSize &&
        _priorityQueues[Priority.low]!.isNotEmpty) {
      final item = _priorityQueues[Priority.low]!.removeFirst();
      if (!_isItemExpired(item, now)) {
        batch.add(item);
      }
    }

    return batch;
  }

  /// Process batch with proper error handling
  Future<void> _processBatch(
    List<QueueItem<T>> batch,
    Future<void> Function(T item) processor,
  ) async {
    final futures = <Future<void>>[];

    for (final item in batch) {
      if (_isDisposed || _isPaused) break;

      futures.add(_processItem(item, processor));

      if (futures.length >= _maxConcurrentTasks) {
        await Future.wait(futures);
        futures.clear();
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  /// Process single item with proper resource tracking
  Future<void> _processItem(
    QueueItem<T> item,
    Future<void> Function(T item) processor,
  ) async {
    final completer = Completer<void>();
    _activeTasks[item.id] = completer;

    try {
      item.cancellationToken?.throwIfCancelled();
      await processor(item.item);
      _totalProcessed++;
      _lastProcessedTime = DateTime.now();

      _notifyQueueEvent(QueueEventType.itemProcessed, item: item.item);
    } catch (e) {
      _totalErrors++;
      _notifyQueueEvent(QueueEventType.error, error: e);
      rethrow;
    } finally {
      _activeTasks.remove(item.id);
      completer.complete();
    }
  }

  /// Start processing if needed
  void _startProcessingIfNeeded() {
    if (!_isProcessing && !_isPaused && isNotEmpty) {
      _notifyQueueEvent(QueueEventType.processing);
    }
  }

  /// Validate queue size
  void _validateQueueSize() {
    if (length >= _maxSize) {
      throw QueueOverflowException(
          'Queue size exceeded limit of $_maxSize items');
    }
  }

  /// Validate batch size
  void _validateQueueSizeForBatch(int batchSize) {
    if (length + batchSize > _maxSize) {
      throw QueueOverflowException(
        'Adding $batchSize items would exceed queue limit of $_maxSize',
      );
    }
  }

  /// Get next item with priority handling
  QueueItem<T>? _getNextItem() {
    final now = DateTime.now();

    // Check high priority queue
    while (_priorityQueues[Priority.high]!.isNotEmpty) {
      final item = _priorityQueues[Priority.high]!.first;
      if (_isItemExpired(item, now)) {
        _priorityQueues[Priority.high]!.removeFirst();
        continue;
      }
      return _priorityQueues[Priority.high]!.removeFirst();
    }

    // Check normal queue
    while (_queue.isNotEmpty) {
      final item = _queue.first;
      if (_isItemExpired(item, now)) {
        _queue.removeFirst();
        continue;
      }
      return _queue.removeFirst();
    }

    // Check low priority queue
    while (_priorityQueues[Priority.low]!.isNotEmpty) {
      final item = _priorityQueues[Priority.low]!.first;
      if (_isItemExpired(item, now)) {
        _priorityQueues[Priority.low]!.removeFirst();
        continue;
      }
      return _priorityQueues[Priority.low]!.removeFirst();
    }

    return null;
  }

  /// Check item expiration
  bool _isItemExpired(QueueItem<T> item, DateTime now) {
    return now.difference(item.addedTime) > item.timeout;
  }

  /// Generate unique ID
  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Handle processing error with proper logging
  void _handleProcessingError(Object error) {
    _totalErrors++;
    _notifyQueueEvent(QueueEventType.error, error: error);

    if (kDebugMode) {
      print('❌ Queue processing error: $error');
    }
  }

  /// Notify queue event with proper validation
  void _notifyQueueEvent(
    QueueEventType type, {
    T? item,
    Object? error,
    int? count,
  }) {
    if (!_eventController.isClosed && !_isDisposed) {
      _eventController.add(QueueEvent(
        type: type,
        item: item,
        error: error,
        count: count,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Proper resource cleanup
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _isProcessing = false;
    _batchTimer?.cancel();

    await Future.wait([
      _batchProcessingController.close(),
      _eventController.close(),
    ]);

    _queue.clear();
    _priorityQueues.values.forEach((q) => q.clear());
    _currentBatch.clear();
    _activeTasks.clear();
    _instances.remove(T);

    if (kDebugMode) {
      print('🧹 QueueManager<$T> disposed');
    }
  }

  /// Check if disposed
  void _throwIfDisposed() {
    if (_isDisposed) {
      throw StateError('QueueManager<$T> has been disposed');
    }
  }
}

/// Queue item with proper generic constraint
class QueueItem<T> {
  final T item;
  final Priority priority;
  final String id;
  final DateTime addedTime;
  final Duration timeout;
  final CancellationToken? cancellationToken;

  QueueItem({
    required this.item,
    required this.priority,
    required this.id,
    required this.addedTime,
    required this.timeout,
    this.cancellationToken,
  });
}

/// Queue processing priority with proper documentation
enum Priority {
  high,
  normal,
  low;

  @override
  String toString() => name;
}

/// Queue event types with proper documentation
enum QueueEventType {
  itemAdded,
  batchAdded,
  itemProcessed,
  processing,
  paused,
  resumed,
  cleared,
  timeout,
  error;

  @override
  String toString() => name;
}

/// Queue event for monitoring with proper type safety
class QueueEvent {
  final QueueEventType type;
  final dynamic item;
  final Object? error;
  final int? count;
  final DateTime timestamp;

  QueueEvent({
    required this.type,
    this.item,
    this.error,
    this.count,
    required this.timestamp,
  });

  @override
  String toString() => 'QueueEvent(type: $type, timestamp: $timestamp)';
}

/// Queue overflow exception with proper error information
class QueueOverflowException implements Exception {
  final String message;

  const QueueOverflowException(this.message);

  @override
  String toString() => 'QueueOverflowException: $message';
}

/// Queue empty exception with proper error information
class QueueEmptyException implements Exception {
  final String message;

  const QueueEmptyException(this.message);

  @override
  String toString() => 'QueueEmptyException: $message';
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
