// lib/core/utils/sync_manager.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import './connectivity_manager.dart';
import './request_manager.dart';

/// Manages data synchronization and offline operations for Pokedex app with
/// comprehensive retry logic and error handling
class SyncManager {
  // Singleton pattern
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  // Core components
  late final SharedPreferences _prefs;
  final ConnectivityManager _connectivityManager = ConnectivityManager();
  final RequestManager _requestManager = RequestManager();
  final StreamController<SyncState> _stateController =
      StreamController<SyncState>.broadcast();
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();
  final Map<String, OfflineOperation> _pendingOperations = {};
  final Map<String, int> _operationFailures = {};

  // State management
  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _isDisposed = false;
  SyncState _currentState = SyncState.idle;
  Timer? _syncTimer;
  Timer? _retryTimer;
  DateTime? _lastSyncAttempt;

  // Sync settings
  static const Duration _syncInterval = Duration(minutes: 15);
  static const Duration _retryInterval = Duration(seconds: 30);
  static const Duration _backoffInterval = Duration(minutes: 5);
  static const Duration _operationTimeout = Duration(seconds: 30);
  static const Duration _maxOperationAge = Duration(days: 7);
  static const String _operationsKey = 'pending_operations';
  static const String _failuresKey = 'operation_failures';
  static const String _lastSyncKey = 'last_sync_attempt';
  static const int _maxRetries = 3;
  static const int _maxConsecutiveFailures = 5;
  static const int _batchSize = 10;

  // Public access
  Stream<SyncState> get stateStream => _stateController.stream;
  Stream<double> get progressStream => _progressController.stream;
  SyncState get currentState => _currentState;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncAttempt => _lastSyncAttempt;
  int get pendingOperationsCount => _pendingOperations.length;

  /// Initialize with proper error handling and state restoration
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize dependencies
      await _connectivityManager.initialize();
      _prefs = await SharedPreferences.getInstance();

      // Restore state
      await Future.wait([
        _loadPendingOperations(),
        _loadOperationFailures(),
        _loadLastSyncAttempt(),
      ]);

      // Start monitoring
      _startPeriodicSync();
      _setupConnectivityListener();
      _isInitialized = true;

      if (kDebugMode) {
        print(
            '✅ SyncManager initialized with ${_pendingOperations.length} pending operations');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ SyncManager initialization failed: $e');
      }
      rethrow;
    }
  }

  /// Load persisted state
  Future<void> _loadPendingOperations() async {
    try {
      final operationsJson = _prefs.getString(_operationsKey);
      if (operationsJson != null) {
        final operations = json.decode(operationsJson) as Map<String, dynamic>;
        operations.forEach((key, value) {
          final operation = OfflineOperation.fromJson(value);
          // Filter out expired operations
          if (DateTime.now().difference(operation.timestamp) <=
              _maxOperationAge) {
            _pendingOperations[key] = operation;
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error loading pending operations: $e');
      }
    }
  }

  Future<void> _loadOperationFailures() async {
    try {
      final failuresJson = _prefs.getString(_failuresKey);
      if (failuresJson != null) {
        final failures = json.decode(failuresJson) as Map<String, dynamic>;
        _operationFailures
            .addAll(failures.map((key, value) => MapEntry(key, value as int)));
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error loading operation failures: $e');
      }
    }
  }

  Future<void> _loadLastSyncAttempt() async {
    try {
      final timestamp = _prefs.getInt(_lastSyncKey);
      if (timestamp != null) {
        _lastSyncAttempt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error loading last sync attempt: $e');
      }
    }
  }

  /// Save state to persistence
  Future<void> _savePendingOperations() async {
    try {
      final operationsJson = json.encode(
        _pendingOperations.map((key, value) => MapEntry(key, value.toJson())),
      );
      await _prefs.setString(_operationsKey, operationsJson);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error saving pending operations: $e');
      }
    }
  }

  Future<void> _saveOperationFailures() async {
    try {
      final failuresJson = json.encode(_operationFailures);
      await _prefs.setString(_failuresKey, failuresJson);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error saving operation failures: $e');
      }
    }
  }

  Future<void> _saveLastSyncAttempt() async {
    try {
      await _prefs.setInt(
          _lastSyncKey, _lastSyncAttempt?.millisecondsSinceEpoch ?? 0);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error saving last sync attempt: $e');
      }
    }
  }

  /// Queue operation for offline sync
  Future<void> queueOfflineOperation(String endpoint) async {
    if (!_isInitialized) await initialize();
    _throwIfDisposed();

    try {
      // Don't queue if already pending
      if (await isOperationQueued(endpoint)) return;

      final operation = OfflineOperation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        endpoint: endpoint,
        timestamp: DateTime.now(),
      );

      _pendingOperations[operation.id] = operation;
      await _savePendingOperations();

      // Start sync if conditions are good
      if (_connectivityManager.isOnline && !_isSyncing) {
        _startSync();
      }

      if (kDebugMode) {
        print('📝 Queued offline operation: ${operation.endpoint}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error queuing operation: $e');
      }
      rethrow;
    }
  }

  /// Check if operation is already queued
  Future<bool> isOperationQueued(String endpoint) async {
    if (!_isInitialized) await initialize();
    return _pendingOperations.values.any((op) => op.endpoint == endpoint);
  }

  /// Start periodic sync with backoff
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      if (!_isSyncing && _pendingOperations.isNotEmpty) {
        await _sync();
      }
    });
  }

  /// Setup connectivity listener for opportunistic sync
  void _setupConnectivityListener() {
    _connectivityManager.networkStateStream.listen((state) {
      if (state.isOnline && !_isSyncing && _pendingOperations.isNotEmpty) {
        _startSync();
      }
    });
  }

  /// Start sync process
  void _startSync() {
    _retryTimer?.cancel();
    _sync();
  }

  /// Execute sync with error handling and retry logic
  Future<void> _sync() async {
    if (_isSyncing || _pendingOperations.isEmpty || _isDisposed) return;

    try {
      _isSyncing = true;
      _lastSyncAttempt = DateTime.now();
      await _saveLastSyncAttempt();
      _updateState(SyncState.syncing);

      final isOnline = _connectivityManager.isOnline;
      if (!isOnline) {
        _updateState(SyncState.waitingForConnection);
        _scheduleRetry(_retryInterval);
        return;
      }

      await _processPendingOperations();

      _isSyncing = false;
      _updateState(SyncState.completed);
      await _cleanupCompletedOperations();

      if (kDebugMode) {
        print('✅ Sync completed');
      }
    } catch (e) {
      _isSyncing = false;
      _updateState(SyncState.error);
      _scheduleRetry(_backoffInterval);

      if (kDebugMode) {
        print('❌ Sync error: $e');
      }
    } finally {
      _updateProgress(1.0);
    }
  }

  /// Schedule retry with appropriate interval
  void _scheduleRetry(Duration interval) {
    _retryTimer?.cancel();
    _retryTimer = Timer(interval, () {
      if (_pendingOperations.isNotEmpty && !_isSyncing) {
        _sync();
      }
    });
  }

  /// Process pending operations in batches with smart retry
  Future<void> _processPendingOperations() async {
    final operations = _pendingOperations.values.toList();
    final totalOperations = operations.length;
    var completedOperations = 0;
    var consecutiveFailures = 0;

    for (var i = 0; i < operations.length; i += _batchSize) {
      if (_isDisposed) return;

      final batch = operations.skip(i).take(_batchSize);

      try {
        await Future.wait(
          batch.map((operation) => _processOperation(operation)),
          eagerError: true,
        );

        completedOperations += batch.length;
        consecutiveFailures = 0;
        _updateProgress(completedOperations / totalOperations);
      } catch (e) {
        consecutiveFailures++;
        if (consecutiveFailures >= _maxConsecutiveFailures) {
          throw Exception('Too many consecutive failures');
        }
        // Add exponential backoff
        await Future.delayed(_retryInterval * (1 << consecutiveFailures));
      }
    }
  }

  /// Process single operation with timeout and retry tracking
  Future<void> _processOperation(OfflineOperation operation) async {
    try {
      final response = await _requestManager.executeRequest(
        id: operation.id,
        request: () async {
          final response = await http
              .get(Uri.parse(operation.endpoint))
              .timeout(_operationTimeout);

          if (response.statusCode != 200) {
            throw HttpException('Failed with status: ${response.statusCode}');
          }
          return response;
        },
      );

      if (response.statusCode == 200) {
        await _handleSuccessfulOperation(operation);
      } else {
        await _handleFailedOperation(operation);
      }
    } catch (e) {
      await _handleOperationError(operation, e);
    }
  }

  /// Handle successful operation completion
  Future<void> _handleSuccessfulOperation(OfflineOperation operation) async {
    _pendingOperations.remove(operation.id);
    _operationFailures.remove(operation.id);
    await Future.wait([
      _savePendingOperations(),
      _saveOperationFailures(),
    ]);

    if (kDebugMode) {
      print('✅ Operation completed: ${operation.endpoint}');
    }
  }

  /// Handle failed operation
  Future<void> _handleFailedOperation(OfflineOperation operation) async {
    operation.retryCount++;
    _operationFailures[operation.id] =
        (_operationFailures[operation.id] ?? 0) + 1;

    if (operation.retryCount >= _maxRetries ||
        (_operationFailures[operation.id] ?? 0) >= _maxConsecutiveFailures) {
      _pendingOperations.remove(operation.id);

      if (kDebugMode) {
        print('❌ Operation failed permanently: ${operation.endpoint}');
      }
    }

    await Future.wait([
      _savePendingOperations(),
      _saveOperationFailures(),
    ]);
  }

  /// Handle operation error
  Future<void> _handleOperationError(
    OfflineOperation operation,
    dynamic error,
  ) async {
    if (kDebugMode) {
      print('⚠️ Operation error: ${operation.endpoint} - $error');
    }

    operation.retryCount++;
    _operationFailures[operation.id] =
        (_operationFailures[operation.id] ?? 0) + 1;

    await Future.wait([
      _savePendingOperations(),
      _saveOperationFailures(),
    ]);

    // Rethrow if max retries exceeded
    if (operation.retryCount >= _maxRetries) {
      throw Exception('Max retries exceeded for operation: ${operation.id}');
    }
  }

  /// Clean up completed and expired operations
  Future<void> _cleanupCompletedOperations() async {
    final now = DateTime.now();
    _pendingOperations.removeWhere((_, operation) {
      return now.difference(operation.timestamp) > _maxOperationAge;
    });
    await _savePendingOperations();
  }

  /// Update sync state with notifications
  void _updateState(SyncState state) {
    _currentState = state;
    if (!_stateController.isClosed && !_isDisposed) {
      _stateController.add(state);
    }
  }

  /// Update sync progress
  void _updateProgress(double progress) {
    if (!_progressController.isClosed && !_isDisposed) {
      _progressController.add(progress.clamp(0.0, 1.0));
    }
  }

  /// Force immediate sync
  Future<void> syncNow() async {
    if (!_isInitialized) await initialize();
    _throwIfDisposed();

    _retryTimer?.cancel();
    await _sync();
  }

  /// Clear sync queue
  Future<void> clearQueue() async {
    _pendingOperations.clear();
    _operationFailures.clear();
    await Future.wait([
      _prefs.remove(_operationsKey),
      _prefs.remove(_failuresKey),
    ]);
    _updateProgress(0);
    _updateState(SyncState.idle);

    if (kDebugMode) {
      print('🧹 Sync queue cleared');
    }
  }

  /// Get sync statistics
  Map<String, dynamic> getSyncStats() {
    return {
      'pendingOperations': _pendingOperations.length,
      'failedOperations': _operationFailures.length,
      'lastSyncAttempt': _lastSyncAttempt?.toIso8601String(),
      'currentState': _currentState.toString(),
      'isOnline': _connectivityManager.isOnline,
    };
  }

  void _throwIfDisposed() {
    if (_isDisposed) {
      throw StateError('SyncManager has been disposed');
    }
  }

  /// Resource cleanup
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _syncTimer?.cancel();
    _retryTimer?.cancel();
    await Future.wait([
      _stateController.close(),
      _progressController.close(),
    ]);
    _pendingOperations.clear();
    _operationFailures.clear();
    _isInitialized = false;

    if (kDebugMode) {
      print('🧹 SyncManager disposed');
    }
  }
}

/// Represents an offline operation with retry tracking
class OfflineOperation {
  final String id;
  final String endpoint;
  final DateTime timestamp;
  int retryCount;

  OfflineOperation({
    required this.id,
    required this.endpoint,
    required this.timestamp,
    this.retryCount = 0,
  });

  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'] as String,
      endpoint: json['endpoint'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'retryCount': retryCount,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineOperation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'OfflineOperation(id: $id, endpoint: $endpoint, retries: $retryCount)';
}

/// Sync state enumeration with helper methods
enum SyncState {
  idle('Idle'),
  syncing('Syncing'),
  waitingForConnection('Waiting for Connection'),
  completed('Completed'),
  error('Error');

  final String status;
  const SyncState(this.status);

  bool get isActive => this == SyncState.syncing;
  bool get needsRetry =>
      this == SyncState.error || this == SyncState.waitingForConnection;
  bool get canRetry =>
      this == SyncState.error || this == SyncState.waitingForConnection;
  bool get isComplete => this == SyncState.completed;

  @override
  String toString() => status;
}
