// lib/core/utils/sync_manager.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import './connectivity_manager.dart';
import './request_manager.dart';
import './prefs_helper.dart';
import './cancellation_token.dart';
import '../constants/api_paths.dart';

/// Manages data synchronization and offline operations with comprehensive
/// retry logic and error handling
class SyncManager {
  // Singleton pattern with thread safety
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  // Core components
  late final SharedPreferences _prefs;
  final ConnectivityManager _connectivityManager = ConnectivityManager();
  final RequestManager _requestManager = RequestManager();
  final _stateController = StreamController<SyncState>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _pendingOperations = <String, OfflineOperation>{};
  final _operationFailures = <String, int>{};
  final _lock = Lock();

  // State management
  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _isDisposed = false;
  SyncState _currentState = SyncState.idle;
  Timer? _syncTimer;
  Timer? _retryTimer;
  DateTime? _lastSyncAttempt;

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

  // Public getters
  Stream<SyncState> get stateStream => _stateController.stream;
  Stream<double> get progressStream => _progressController.stream;
  SyncState get currentState => _currentState;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncAttempt => _lastSyncAttempt;
  int get pendingOperationsCount => _pendingOperations.length;

  /// Initialize with proper error handling and state restoration
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      await _lock.synchronized(() async {
        await _connectivityManager.initialize();
        _prefs = await PrefsHelper.instance.prefs;

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
      });

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

  /// Load persisted operations
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

  /// Queue operation for offline sync
  Future<void> queueOfflineOperation(String endpoint) async {
    if (!_isInitialized) await initialize();

    await _lock.synchronized(() async {
      final operation = OfflineOperation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        endpoint: endpoint,
        timestamp: DateTime.now(),
      );

      _pendingOperations[operation.id] = operation;
      await _savePendingOperations();

      if (_connectivityManager.isOnline && !_isSyncing) {
        _startSync();
      }

      if (kDebugMode) {
        print('📝 Queued offline operation: ${operation.endpoint}');
      }
    });
  }

  /// Process pending operations with batching
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
        await Future.delayed(_retryInterval * (1 << consecutiveFailures));
      }
    }
  }

  /// Process single operation with timeout and retry
  Future<void> _processOperation(OfflineOperation operation) async {
    try {
      final token = CancellationToken.withTimeout(_operationTimeout);

      final response = await _requestManager.executeRequest(
        id: operation.id,
        request: () async {
          final response = await http.get(Uri.parse(operation.endpoint));
          token.throwIfCancelled();

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
    await _lock.synchronized(() async {
      _pendingOperations.remove(operation.id);
      _operationFailures.remove(operation.id);
      await Future.wait([
        _savePendingOperations(),
        _saveOperationFailures(),
      ]);
    });

    if (kDebugMode) {
      print('✅ Operation completed: ${operation.endpoint}');
    }
  }

  /// Clean resource disposal
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

/// Offline operation with retry tracking
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

/// Thread-safe lock implementation
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
