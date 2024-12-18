// lib/core/utils/sync_manager.dart

/// Sync manager to handle data synchronization between local and remote storage.
/// Ensures data consistency and handles offline-to-online synchronization.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:rxdart/subjects.dart';

import 'connectivity_manager.dart';
import 'cache_manager.dart';

/// Status of sync operation
enum SyncStatus {
  /// Initial state
  initial,

  /// Sync in progress
  syncing,

  /// Sync completed successfully
  completed,

  /// Sync failed
  failed,

  /// Offline mode active
  offline
}

/// Entry in sync queue
class SyncEntry {
  /// Unique identifier for sync entry
  final String id;

  /// Type of operation
  final String operation;

  /// Data to sync
  final Map<String, dynamic> data;

  /// Timestamp of creation
  final DateTime timestamp;

  /// Number of retry attempts
  int retryCount;

  /// Constructor
  SyncEntry({
    required this.id,
    required this.operation,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'operation': operation,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'retryCount': retryCount,
      };

  /// Create from JSON
  factory SyncEntry.fromJson(Map<String, dynamic> json) => SyncEntry(
        id: json['id'] as String,
        operation: json['operation'] as String,
        data: json['data'] as Map<String, dynamic>,
        timestamp: DateTime.parse(json['timestamp'] as String),
        retryCount: json['retryCount'] as int,
      );
}

/// Manager class for data synchronization
class SyncManager {
  static final SyncManager _instance = SyncManager._internal();

  /// Singleton instance
  factory SyncManager() => _instance;

  SyncManager._internal();

  final ConnectivityManager _connectivityManager = ConnectivityManager();
  late final CacheManager _cacheManager;
  final BehaviorSubject<SyncStatus> _statusController =
      BehaviorSubject<SyncStatus>.seeded(SyncStatus.initial);
  final List<SyncEntry> _syncQueue = [];

  Timer? _syncTimer;
  bool _isSyncing = false;
  static const String _syncQueueKey = 'sync_queue';
  static const Duration _syncInterval = Duration(minutes: 5);
  static const int _maxRetries = 3;

  /// Initialize sync manager
  Future<void> initialize() async {
    _cacheManager = await CacheManager.initialize();
    await _loadSyncQueue();
    _setupSyncTimer();
    _listenToConnectivity();
  }

  /// Stream of sync status changes
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Current sync status
  SyncStatus get currentStatus => _statusController.value;

  /// Setup periodic sync timer
  void _setupSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) => sync());
  }

  /// Listen to connectivity changes
  void _listenToConnectivity() {
    _connectivityManager.connectionStream.listen((state) {
      if (state == NetworkState.online && _syncQueue.isNotEmpty) {
        sync();
      }
    });
  }

  /// Add operation to sync queue
  Future<void> addToSyncQueue({
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    final entry = SyncEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      operation: operation,
      data: data,
      timestamp: DateTime.now(),
    );

    _syncQueue.add(entry);
    await _saveSyncQueue();

    if (_connectivityManager.hasConnection) {
      sync();
    }
  }

  /// Load sync queue from storage
  Future<void> _loadSyncQueue() async {
    final String? queueJson = await _cacheManager.get<String>(_syncQueueKey);
    if (queueJson != null) {
      final List<dynamic> queueData = await compute(json.decode, queueJson);
      _syncQueue.clear();
      _syncQueue.addAll(queueData
          .map((item) => SyncEntry.fromJson(item as Map<String, dynamic>)));
    }
  }

  /// Save sync queue to storage
  Future<void> _saveSyncQueue() async {
    final queueData = _syncQueue.map((e) => e.toJson()).toList();
    final queueJson = await compute(json.encode, queueData);
    await _cacheManager.put(_syncQueueKey, queueJson);
  }

  /// Perform sync operation
  Future<void> sync() async {
    if (_isSyncing ||
        _syncQueue.isEmpty ||
        !_connectivityManager.hasConnection) {
      return;
    }

    _isSyncing = true;
    _statusController.add(SyncStatus.syncing);

    try {
      final entriesCopy = List<SyncEntry>.from(_syncQueue);
      for (final entry in entriesCopy) {
        final success = await _processSyncEntry(entry);
        if (success) {
          _syncQueue.remove(entry);
        } else if (entry.retryCount >= _maxRetries) {
          _syncQueue.remove(entry);
        } else {
          entry.retryCount++;
        }
      }

      await _saveSyncQueue();
      _statusController
          .add(_syncQueue.isEmpty ? SyncStatus.completed : SyncStatus.failed);
    } catch (e) {
      _statusController.add(SyncStatus.failed);
    } finally {
      _isSyncing = false;
    }
  }

  /// Process individual sync entry
  Future<bool> _processSyncEntry(SyncEntry entry) async {
    try {
      // Implementation depends on operation type
      switch (entry.operation) {
        case 'updateFavorite':
          // Handle favorite update
          return true;
        case 'updateNote':
          // Handle note update
          return true;
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Clear sync queue
  Future<void> clearSyncQueue() async {
    _syncQueue.clear();
    await _saveSyncQueue();
  }

  /// Clean up resources
  void dispose() {
    _syncTimer?.cancel();
    _statusController.close();
  }
}
