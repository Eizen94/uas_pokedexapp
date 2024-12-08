// lib/core/utils/sync_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages data synchronization and offline data handling
class SyncManager {
  // Singleton pattern
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal() {
    _initializeStreams();
  }

  // Core components
  late final SharedPreferences _prefs;
  final _syncQueue = <SyncOperation>[];
  final _syncHistory = <String, SyncResult>{};

  // Stream controllers
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  final _syncProgressController = StreamController<SyncProgress>.broadcast();
  final _syncErrorController = StreamController<SyncError>.broadcast();

  // Sync state
  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isInitialized = false;
  DateTime? _lastSyncTime;
  int _consecutiveFailures = 0;

  // Constants
  static const Duration _syncInterval = Duration(minutes: 15);
  static const Duration _retryDelay = Duration(seconds: 30);
  static const Duration _timeout = Duration(minutes: 2);
  static const int _maxRetries = 3;
  static const int _maxConsecutiveFailures = 5;
  static const String _lastSyncKey = 'last_sync_timestamp';

  // Stream getters
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;
  Stream<SyncProgress> get syncProgress => _syncProgressController.stream;
  Stream<SyncError> get syncErrors => _syncErrorController.stream;

  /// Initialize sync manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadLastSyncTime();
      _isInitialized = true;

      if (kDebugMode) {
        print('✅ SyncManager initialized');
      }
      return;
    } catch (e) {
      if (kDebugMode) {
        print('❌ SyncManager initialization error: $e');
      }
      rethrow;
    }
  }

  /// Initialize stream controllers
  void _initializeStreams() {
    _syncStatusController.add(SyncStatus.idle);
    _syncProgressController.add(SyncProgress(
      totalOperations: 0,
      completedOperations: 0,
      currentOperation: null,
    ));
  }

  /// Start periodic sync
  Future<void> startSync({bool force = false}) async {
    if (_isSyncing && !force) return;

    try {
      _isSyncing = true;
      _syncStatusController.add(SyncStatus.inProgress);

      if (kDebugMode) {
        print('🔄 Starting sync...');
      }

      await _processSyncQueue();

      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();
      _consecutiveFailures = 0;

      _syncStatusController.add(SyncStatus.completed);

      if (kDebugMode) {
        print('✅ Sync completed');
      }
      return;
    } catch (e) {
      _handleSyncError(e);
    } finally {
      _isSyncing = false;
    }
  }

  /// Stop sync process
  Future<void> stopSync() async {
    _syncTimer?.cancel();
    _isSyncing = false;
    _syncStatusController.add(SyncStatus.idle);

    if (kDebugMode) {
      print('⏹️ Sync stopped');
    }
    return;
  }

  /// Add operation to sync queue
  Future<void> addToSyncQueue(SyncOperation operation) async {
    _syncQueue.add(operation);
    _updateProgress();

    if (kDebugMode) {
      print('📝 Added operation to sync queue: ${operation.id}');
    }
    return;
  }

  /// Process sync queue
  Future<void> _processSyncQueue() async {
    final totalOperations = _syncQueue.length;
    int completedOperations = 0;

    while (_syncQueue.isNotEmpty) {
      final operation = _syncQueue.first;

      try {
        _updateProgress(
          currentOperation: operation,
          totalOperations: totalOperations,
          completedOperations: completedOperations,
        );

        await _executeOperation(operation);

        _syncQueue.removeAt(0);
        completedOperations++;

        _syncHistory[operation.id] = SyncResult(
          operation: operation,
          status: SyncStatus.completed,
          timestamp: DateTime.now(),
        );
      } catch (e) {
        if (await _handleOperationError(operation, e)) {
          // Retry operation later
          _syncQueue.removeAt(0);
          _syncQueue.add(operation);
        } else {
          // Operation failed permanently
          _syncQueue.removeAt(0);
          _syncHistory[operation.id] = SyncResult(
            operation: operation,
            status: SyncStatus.failed,
            timestamp: DateTime.now(),
            error: e.toString(),
          );
        }
      }
    }
    return;
  }

  /// Execute single operation
  Future<void> _executeOperation(SyncOperation operation) async {
    if (operation.retryCount >= _maxRetries) {
      throw MaxRetriesExceededException();
    }

    try {
      await operation.execute().timeout(_timeout);
      return;
    } catch (e) {
      operation.retryCount++;
      rethrow;
    }
  }

  /// Handle operation error
  Future<bool> _handleOperationError(
    SyncOperation operation,
    dynamic error,
  ) async {
    if (kDebugMode) {
      print('❌ Operation failed: ${operation.id} - $error');
    }

    _syncErrorController.add(SyncError(
      operation: operation,
      error: error.toString(),
      timestamp: DateTime.now(),
    ));

    // Check if operation should be retried
    if (operation.retryCount < _maxRetries) {
      await Future.delayed(_retryDelay);
      return true;
    }

    return false;
  }

  /// Handle sync error
  void _handleSyncError(dynamic error) {
    _consecutiveFailures++;

    if (kDebugMode) {
      print('❌ Sync error: $error');
    }

    _syncStatusController.add(SyncStatus.failed);
    _syncErrorController.add(SyncError(
      error: error.toString(),
      timestamp: DateTime.now(),
    ));

    // Stop sync if too many failures
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      stopSync();
    }
  }

  /// Update sync progress
  void _updateProgress({
    SyncOperation? currentOperation,
    int totalOperations = 0,
    int completedOperations = 0,
  }) {
    if (!_syncProgressController.isClosed) {
      _syncProgressController.add(SyncProgress(
        totalOperations: totalOperations,
        completedOperations: completedOperations,
        currentOperation: currentOperation,
      ));
    }
  }

  /// Load last sync time
  Future<void> _loadLastSyncTime() async {
    final timestamp = _prefs.getInt(_lastSyncKey);
    if (timestamp != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return;
  }

  /// Save last sync time
  Future<void> _saveLastSyncTime() async {
    if (_lastSyncTime != null) {
      await _prefs.setInt(
        _lastSyncKey,
        _lastSyncTime!.millisecondsSinceEpoch,
      );
    }
    return;
  }

  /// Get sync history
  List<SyncResult> getSyncHistory() {
    return _syncHistory.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Get time since last sync
  Duration? getTimeSinceLastSync() {
    if (_lastSyncTime == null) return null;
    return DateTime.now().difference(_lastSyncTime!);
  }

  /// Check if sync is needed
  bool needsSync() {
    if (_lastSyncTime == null) return true;
    return DateTime.now().difference(_lastSyncTime!) > _syncInterval;
  }

  /// Get current sync status
  SyncStatus getCurrentStatus() {
    if (_isSyncing) return SyncStatus.inProgress;
    if (_consecutiveFailures > 0) return SyncStatus.failed;
    return SyncStatus.idle;
  }

  /// Reset sync state
  void reset() {
    _syncQueue.clear();
    _syncHistory.clear();
    _consecutiveFailures = 0;
    _updateProgress();
  }

  /// Cleanup resources
  Future<void> dispose() async {
    _syncTimer?.cancel();
    await stopSync();

    await Future.wait([
      _syncStatusController.close(),
      _syncProgressController.close(),
      _syncErrorController.close(),
    ]);

    if (kDebugMode) {
      print('🧹 SyncManager disposed');
    }
  }
}

/// Sync operation base class
abstract class SyncOperation {
  final String id;
  final SyncPriority priority;
  int retryCount;

  SyncOperation({
    required this.id,
    this.priority = SyncPriority.normal,
  }) : retryCount = 0;

  Future<void> execute();
}

/// Sync operation result
class SyncResult {
  final SyncOperation? operation;
  final SyncStatus status;
  final DateTime timestamp;
  final String? error;

  SyncResult({
    this.operation,
    required this.status,
    required this.timestamp,
    this.error,
  });
}

/// Sync progress information
class SyncProgress {
  final int totalOperations;
  final int completedOperations;
  final SyncOperation? currentOperation;

  SyncProgress({
    required this.totalOperations,
    required this.completedOperations,
    this.currentOperation,
  });

  double get percentComplete {
    if (totalOperations == 0) return 0;
    return (completedOperations / totalOperations) * 100;
  }

  @override
  String toString() =>
      'Progress: $completedOperations/$totalOperations (${percentComplete.toStringAsFixed(1)}%)';
}

/// Sync error information
class SyncError {
  final SyncOperation? operation;
  final String error;
  final DateTime timestamp;

  SyncError({
    this.operation,
    required this.error,
    required this.timestamp,
  });

  @override
  String toString() => 'SyncError: ${operation?.id ?? 'General'} - $error';
}

/// Sync priority levels
enum SyncPriority {
  high,
  normal,
  low;

  bool get isHigh => this == SyncPriority.high;
  bool get isNormal => this == SyncPriority.normal;
  bool get isLow => this == SyncPriority.low;
}

/// Sync status
enum SyncStatus {
  idle('Idle'),
  inProgress('In Progress'),
  completed('Completed'),
  failed('Failed');

  final String value;
  const SyncStatus(this.value);

  bool get isIdle => this == SyncStatus.idle;
  bool get isInProgress => this == SyncStatus.inProgress;
  bool get isCompleted => this == SyncStatus.completed;
  bool get isFailed => this == SyncStatus.failed;

  @override
  String toString() => value;
}

/// Custom exceptions
class MaxRetriesExceededException implements Exception {
  @override
  String toString() => 'Maximum retry attempts exceeded';
}
