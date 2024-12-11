// lib/core/utils/sync_manager.dart

// Dart imports
import 'dart:async';
import 'dart:convert';

// Package imports
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Local imports
import '../constants/api_paths.dart';
import 'connectivity_manager.dart';
import 'request_manager.dart';
import 'prefs_helper.dart';
import 'cancellation_token.dart';
import 'monitoring_manager.dart';

/// Enhanced sync manager for data synchronization and offline operations.
/// Provides comprehensive sync lifecycle management with proper error handling.
class SyncManager {
  // Singleton implementation
  static SyncManager? _instance;
  static final _lock = Object();

  // Core components
  final ConnectivityManager _connectivityManager = ConnectivityManager();
  final RequestManager _requestManager = RequestManager();
  final _stateController = StreamController<SyncState>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final Map<String, OfflineOperation> _pendingOperations = {};
  final Map<String, int> _operationFailures = {};

  // State management
  late final PrefsHelper _prefsHelper;
  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _isDisposed = false;
  SyncState _currentState = SyncState.idle;
  Timer? _syncTimer;
  Timer? _retryTimer;
  DateTime? _lastSyncAttempt;
  CancellationToken? _currentSyncToken;

  // Constants
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

  // Private constructor
  SyncManager._internal();

  // Factory constructor
  factory SyncManager() => _instance ??= SyncManager._internal();

  // Getters
  Stream<SyncState> get stateStream => _stateController.stream;
  Stream<double> get progressStream => _progressController.stream;
  SyncState get currentState => _currentState;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncAttempt => _lastSyncAttempt;
  int get pendingOperationsCount => _pendingOperations.length;

  /// Initialize with proper error handling
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      await _lock.synchronized(() async {
        // Initialize dependencies
        await _connectivityManager.initialize();
        _prefsHelper = await PrefsHelper.getInstance();

        // Restore state
        await Future.wait([
          _loadPendingOperations(),
          _loadOperationFailures(),
          _loadLastSyncAttempt(),
        ]);

        // Start monitoring
        _setupConnectivityListener();
        _startPeriodicSync();

        _isInitialized = true;
      });

      if (kDebugMode) {
        print(
            '✅ SyncManager initialized with ${_pendingOperations.length} operations');
      }
    } catch (e) {
      _handleError(SyncError(
        type: SyncErrorType.initialization,
        message: 'Failed to initialize: $e',
      ));
      rethrow;
    }
  }

  /// Start periodic sync
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      if (_shouldSync()) {
        _startSync();
      }
    });
  }

  /// Setup connectivity listener
  void _setupConnectivityListener() {
    _connectivityManager.networkStateStream.listen((state) {
      if (state.isOnline && _shouldSync()) {
        _startSync();
      }
    });
  }

  /// Check if sync is needed
  bool _shouldSync() {
    if (_isSyncing || _isDisposed) return false;
    if (_lastSyncAttempt == null) return true;

    final timeSinceLastSync = DateTime.now().difference(_lastSyncAttempt!);
    return timeSinceLastSync >= _syncInterval;
  }

  /// Start sync process
  Future<void> _startSync() async {
    if (_isSyncing || _isDisposed) return;

    _isSyncing = true;
    _currentSyncToken = CancellationToken();
    _updateState(SyncState.syncing);

    try {
      // Process pending operations in batches
      final operations = _pendingOperations.values.toList();
      final totalOperations = operations.length;
      var completedOperations = 0;

      for (var i = 0; i < operations.length; i += _batchSize) {
        if (_isDisposed || _currentSyncToken?.isCancelled == true) break;

        final batch = operations.skip(i).take(_batchSize);
        await _processBatch(batch);

        completedOperations += batch.length;
        _updateProgress(completedOperations / totalOperations);
      }

      _lastSyncAttempt = DateTime.now();
      await _persistSyncState();
      _updateState(SyncState.completed);
    } catch (e) {
      _handleError(SyncError(
        type: SyncErrorType.sync,
        message: 'Sync failed: $e',
      ));
      _updateState(SyncState.error);
    } finally {
      _isSyncing = false;
      _currentSyncToken = null;
    }
  }

  /// Process batch of operations
  Future<void> _processBatch(Iterable<OfflineOperation> batch) async {
    try {
      await Future.wait(
        batch.map((operation) => _processOperation(operation)),
        eagerError: true,
      );
    } catch (e) {
      _handleError(SyncError(
        type: SyncErrorType.batch,
        message: 'Batch processing failed: $e',
      ));
      rethrow;
    }
  }

  /// Process single operation
  Future<void> _processOperation(OfflineOperation operation) async {
    try {
      _currentSyncToken?.throwIfCancelled();

      final response = await _requestManager.executeRequest(
        id: operation.id,
        request: () => http.get(Uri.parse(operation.endpoint)),
        timeout: _operationTimeout,
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

  /// Handle successful operation
  Future<void> _handleSuccessfulOperation(OfflineOperation operation) async {
    await _lock.synchronized(() async {
      _pendingOperations.remove(operation.id);
      _operationFailures.remove(operation.id);
      await Future.wait([
        _persistPendingOperations(),
        _persistOperationFailures(),
      ]);
    });
  }

  /// Handle failed operation
  Future<void> _handleFailedOperation(OfflineOperation operation) async {
    final failures = _operationFailures[operation.id] ?? 0;

    if (failures < _maxRetries) {
      _operationFailures[operation.id] = failures + 1;
      await _persistOperationFailures();
    } else {
      await _lock.synchronized(() async {
        _pendingOperations.remove(operation.id);
        _operationFailures.remove(operation.id);
        await Future.wait([
          _persistPendingOperations(),
          _persistOperationFailures(),
        ]);
      });
    }
  }

  /// Handle operation error
  Future<void> _handleOperationError(
    OfflineOperation operation,
    Object error,
  ) async {
    _handleError(SyncError(
      type: SyncErrorType.operation,
      message: 'Operation failed: $error',
      operation: operation,
    ));

    await _handleFailedOperation(operation);
  }

  /// Queue operation for offline sync
  Future<void> queueOfflineOperation(String endpoint) async {
    if (!_isInitialized) {
      throw StateError('SyncManager not initialized');
    }

    await _lock.synchronized(() async {
      final operation = OfflineOperation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        endpoint: endpoint,
        timestamp: DateTime.now(),
      );

      _pendingOperations[operation.id] = operation;
      await _persistPendingOperations();

      if (_connectivityManager.isOnline && !_isSyncing) {
        _startSync();
      }
    });
  }

  /// Load persisted operations
  Future<void> _loadPendingOperations() async {
    try {
      final json = _prefsHelper.prefs.getString(_operationsKey);
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        final now = DateTime.now();

        data.forEach((key, value) {
          final operation = OfflineOperation.fromJson(value);
          if (now.difference(operation.timestamp) <= _maxOperationAge) {
            _pendingOperations[key] = operation;
          }
        });
      }
    } catch (e) {
      _handleError(SyncError(
        type: SyncErrorType.storage,
        message: 'Failed to load operations: $e',
      ));
    }
  }

  /// Persist pending operations
  Future<void> _persistPendingOperations() async {
    try {
      final data = {
        for (var entry in _pendingOperations.entries)
          entry.key: entry.value.toJson()
      };

      await _prefsHelper.prefs.setString(_operationsKey, jsonEncode(data));
    } catch (e) {
      _handleError(SyncError(
        type: SyncErrorType.storage,
        message: 'Failed to persist operations: $e',
      ));
    }
  }

  /// Load operation failures
  Future<void> _loadOperationFailures() async {
    try {
      final json = _prefsHelper.prefs.getString(_failuresKey);
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        _operationFailures.clear();
        _operationFailures.addAll(
          data.map((key, value) => MapEntry(key, value as int)),
        );
      }
    } catch (e) {
      _handleError(SyncError(
        type: SyncErrorType.storage,
        message: 'Failed to load failures: $e',
      ));
    }
  }

  /// Persist operation failures
  Future<void> _persistOperationFailures() async {
    try {
      await _prefsHelper.prefs.setString(
        _failuresKey,
        jsonEncode(_operationFailures),
      );
    } catch (e) {
      _handleError(SyncError(
        type: SyncErrorType.storage,
        message: 'Failed to persist failures: $e',
      ));
    }
  }

  /// Load last sync attempt
  Future<void> _loadLastSyncAttempt() async {
    try {
      final timestamp = _prefsHelper.prefs.getInt(_lastSyncKey);
      if (timestamp != null) {
        _lastSyncAttempt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      _handleError(SyncError(
        type: SyncErrorType.storage,
        message: 'Failed to load last sync: $e',
      ));
    }
  }

  /// Persist sync state
  Future<void> _persistSyncState() async {
    try {
      await _prefsHelper.prefs.setInt(
        _lastSyncKey,
        _lastSyncAttempt?.millisecondsSinceEpoch ?? 0,
      );
    } catch (e) {
      _handleError(SyncError(
        type: SyncErrorType.storage,
        message: 'Failed to persist sync state: $e',
      ));
    }
  }

  /// Update sync state
  void _updateState(SyncState state) {
    if (_isDisposed) return;

    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  /// Update sync progress
  void _updateProgress(double progress) {
    if (_isDisposed) return;

    if (!_progressController.isClosed) {
      _progressController.add(progress.clamp(0.0, 1.0));
    }
  }

  /// Handle sync error
  void _handleError(SyncError error) {
    if (kDebugMode) {
      print('❌ Sync error: ${error.message}');
    }
  }

  /// Cancel current sync
  void cancelSync() {
    _currentSyncToken?.cancel(reason: 'Sync cancelled by user');
  }

  /// Reset sync manager
  Future<void> reset() async {
    await _lock.synchronized(() async {
      cancelSync();
      _pendingOperations.clear();
      _operationFailures.clear();
      _lastSyncAttempt = null;

      await Future.wait([
        _persistPendingOperations(),
        _persistOperationFailures(),
        _persistSyncState(),
      ]);

      _updateState(SyncState.idle);
    });
  }

  /// Resource cleanup
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    cancelSync();
    _syncTimer?.cancel();
    _retryTimer?.cancel();

    await Future.wait([
      _stateController.close(),
      _progressController.close(),
    ]);

    _pendingOperations.clear();
    _operationFailures.clear();
    _instance = null;

    if (kDebugMode) {
      print('🧹 SyncManager disposed');
    }
  }
}

/// Offline operation tracking
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
      identical(this, other) || other is OfflineOperation && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'OfflineOperation(id: $id, endpoint: $endpoint)';
}

/// Sync state enum
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

  bool get isComplete => this == SyncState.completed;

  @override
  String toString() => status;
}

/// Sync error types
enum SyncErrorType { initialization, sync, operation, batch, storage, network }

/// Sync error tracking
class SyncError {
  final SyncErrorType type;
  final String message;
  final OfflineOperation? operation;
  final DateTime timestamp;

  SyncError({
    required this.type,
    required this.message,
    this.operation,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'SyncError(type: $type, message: $message)';
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
