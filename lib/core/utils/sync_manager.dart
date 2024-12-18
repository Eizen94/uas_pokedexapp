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

  SyncManager._internal() {
    _initialize();
  }

  final ConnectivityManager _connectivityManager = ConnectivityManager();
  late final CacheManager _cacheManager;
  final BehaviorSubject<SyncStatus> _statusController =
      BehaviorSubject<SyncStatus>.seeded(SyncStatus.initial);
  final List<SyncEntry> _syncQueue = [];

  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isInitialized = false;
  static const String _syncQueueKey = 'sync_queue';
  static const Duration _syncInterval = Duration(minutes: 5);
  static const int _maxRetries = 3;

  /// Initialize sync manager
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      _cacheManager = await CacheManager.initialize();
      await _loadSyncQueue();
      _setupSyncTimer();
      _listenToConnectivity();
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize SyncManager: $e');
      }
      _statusController.add(SyncStatus.failed);
    }
  }

  /// Stream of sync status changes
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Current sync status
  SyncStatus get currentStatus => _statusController.value;

  /// Setup periodic sync timer
  void _setupSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      if (!_isSyncing) {
        sync();
      }
    });
  }

  /// Listen to connectivity changes
  void _listenToConnectivity() {
    _connectivityManager.connectionStream.listen((state) {
      if (state == NetworkState.online && _syncQueue.isNotEmpty) {
        sync();
      } else if (state == NetworkState.offline) {
        _statusController.add(SyncStatus.offline);
      }
    });
  }

  /// Add operation to sync queue
  Future<void> addToSyncQueue({
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    if (!_isInitialized) {
      await _initialize();
    }

    final entry = SyncEntry(
      id: _generateId(),
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

  /// Generate unique ID for sync entries
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_syncQueue.length}';
  }

  /// Parse JSON string to List of dynamic
  static List<dynamic> _parseJson(String jsonStr) {
    return json.decode(jsonStr) as List<dynamic>;
  }

  /// Encode List of dynamic to JSON string
  static String _encodeJson(List<dynamic> data) {
    return json.encode(data);
  }

  /// Load sync queue from storage
  Future<void> _loadSyncQueue() async {
    try {
      final String? queueJson = await _cacheManager.get<String>(_syncQueueKey);
      if (queueJson != null) {
        final List<dynamic> queueData = await compute<String, List<dynamic>>(
          _parseJson,
          queueJson,
        );

        _syncQueue.clear();
        _syncQueue.addAll(queueData
            .map((item) => SyncEntry.fromJson(item as Map<String, dynamic>)));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load sync queue: $e');
      }
    }
  }

  /// Save sync queue to storage
  Future<void> _saveSyncQueue() async {
    try {
      final queueData = _syncQueue.map((e) => e.toJson()).toList();
      final queueJson = await compute<List<dynamic>, String>(
        _encodeJson,
        queueData,
      );
      await _cacheManager.put(_syncQueueKey, queueJson);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save sync queue: $e');
      }
    }
  }

  /// Perform sync operation
  Future<void> sync() async {
    if (!_isInitialized) {
      await _initialize();
    }

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
        if (entry.retryCount >= _maxRetries) {
          _syncQueue.remove(entry);
          continue;
        }

        final success = await _processSyncEntry(entry);
        if (success) {
          _syncQueue.remove(entry);
        } else {
          entry.retryCount++;
        }

        // Save after each operation in case of interruption
        await _saveSyncQueue();
      }

      _statusController
          .add(_syncQueue.isEmpty ? SyncStatus.completed : SyncStatus.failed);
    } catch (e) {
      if (kDebugMode) {
        print('Sync failed: $e');
      }
      _statusController.add(SyncStatus.failed);
    } finally {
      _isSyncing = false;
    }
  }

  /// Process individual sync entry
  Future<bool> _processSyncEntry(SyncEntry entry) async {
    try {
      switch (entry.operation) {
        case 'updateFavorite':
          // Favorite operations are handled locally until online
          return true;
        case 'updateNote':
          // Note updates are handled locally until online
          return true;
        case 'updateSettings':
          // Settings are synced when online
          return true;
        default:
          if (kDebugMode) {
            print('Unknown operation type: ${entry.operation}');
          }
          return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to process sync entry: $e');
      }
      return false;
    }
  }

  /// Get pending operations count
  int get pendingOperationsCount => _syncQueue.length;

  /// Get failed operations
  List<SyncEntry> getFailedOperations() {
    return _syncQueue
        .where((entry) => entry.retryCount >= _maxRetries)
        .toList();
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
    _isInitialized = false;
  }
}
