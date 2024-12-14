// lib/core/utils/offline_operation.dart

/// Offline operation handler for managing operations when device is offline.
/// Ensures data consistency and operation queuing during offline periods.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/subjects.dart';

import 'cache_manager.dart';
import 'connectivity_manager.dart';
import 'monitoring_manager.dart';
import 'sync_manager.dart';

/// Operation types that can be performed offline
enum OfflineOperationType {
  /// Add to favorites
  addFavorite,
  
  /// Remove from favorites
  removeFavorite,
  
  /// Add note
  addNote,
  
  /// Update note
  updateNote,
  
  /// Delete note
  deleteNote,
  
  /// Update settings
  updateSettings
}

/// Status of offline operation
enum OfflineOperationStatus {
  /// Operation is pending
  pending,
  
  /// Operation is being processed
  processing,
  
  /// Operation completed successfully
  completed,
  
  /// Operation failed
  failed
}

/// Offline operation entry
class OfflineOperation {
  /// Unique operation ID
  final String id;
  
  /// Operation type
  final OfflineOperationType type;
  
  /// Operation data
  final Map<String, dynamic> data;
  
  /// Creation timestamp
  final DateTime timestamp;
  
  /// Current status
  OfflineOperationStatus status;
  
  /// Error message if failed
  String? error;

  OfflineOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.status = OfflineOperationStatus.pending,
    this.error,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'status': status.name,
    if (error != null) 'error': error,
  };

  /// Create from JSON
  factory OfflineOperation.fromJson(Map<String, dynamic> json) => OfflineOperation(
    id: json['id'] as String,
    type: OfflineOperationType.values.firstWhere(
      (e) => e.name == json['type'],
    ),
    data: json['data'] as Map<String, dynamic>,
    timestamp: DateTime.parse(json['timestamp'] as String),
    status: OfflineOperationStatus.values.firstWhere(
      (e) => e.name == json['status'],
    ),
    error: json['error'] as String?,
  );
}

/// Manager class for offline operations
class OfflineOperationManager {
  static final OfflineOperationManager _instance = OfflineOperationManager._internal();
  
  /// Singleton instance
  factory OfflineOperationManager() => _instance;

  OfflineOperationManager._internal();

  final ConnectivityManager _connectivityManager = ConnectivityManager();
  final SyncManager _syncManager = SyncManager();
  final CacheManager _cacheManager;
  final MonitoringManager _monitoringManager = MonitoringManager();
  
  final BehaviorSubject<List<OfflineOperation>> _operationsController = 
      BehaviorSubject<List<OfflineOperation>>.seeded([]);
  
  final List<OfflineOperation> _operations = [];
  static const String _operationsKey = 'offline_operations';

  /// Initialize manager
  static Future<OfflineOperationManager> initialize() async {
    final instance = OfflineOperationManager();
    instance._cacheManager = await CacheManager.initialize();
    await instance._loadOperations();
    instance._setupConnectivityListener();
    return instance;
  }

  /// Stream of offline operations
  Stream<List<OfflineOperation>> get operationsStream => 
      _operationsController.stream;

  /// Add new offline operation
  Future<void> addOperation({
    required OfflineOperationType type,
    required Map<String, dynamic> data,
  }) async {
    final operation = OfflineOperation(
      id: _generateOperationId(),
      type: type,
      data: data,
      timestamp: DateTime.now(),
    );

    _operations.add(operation);
    await _saveOperations();
    _updateOperations();

    if (_connectivityManager.hasConnection) {
      processOperations();
    }
  }

  /// Process pending operations
  Future<void> processOperations() async {
    final pendingOperations = _operations
        .where((op) => op.status == OfflineOperationStatus.pending)
        .toList();

    for (final operation in pendingOperations) {
      try {
        operation.status = OfflineOperationStatus.processing;
        _updateOperations();

        await _processOperation(operation);
        
        operation.status = OfflineOperationStatus.completed;
      } catch (e) {
        operation.status = OfflineOperationStatus.failed;
        operation.error = e.toString();
        
        _monitoringManager.logError(
          'Failed to process offline operation',
          error: e,
          additionalData: {
            'operationId': operation.id,
            'type': operation.type.name,
          },
        );
      }
      
      _updateOperations();
      await _saveOperations();
    }
  }

  /// Process single operation
  Future<void> _processOperation(OfflineOperation operation) async {
    switch (operation.type) {
      case OfflineOperationType.addFavorite:
      case OfflineOperationType.removeFavorite:
        await _syncManager.addToSyncQueue(
          operation: operation.type.name,
          data: operation.data,
        );
        break;
        
      case OfflineOperationType.addNote:
      case OfflineOperationType.updateNote:
      case OfflineOperationType.deleteNote:
        await _syncManager.addToSyncQueue(
          operation: operation.type.name,
          data: operation.data,
        );
        break;
        
      case OfflineOperationType.updateSettings:
        await _syncManager.addToSyncQueue(
          operation: operation.type.name,
          data: operation.data,
        );
        break;
    }
  }

  /// Load saved operations
  Future<void> _loadOperations() async {
    final data = await _cacheManager.get<List<dynamic>>(_operationsKey);
    if (data != null) {
      _operations.clear();
      _operations.addAll(
        data.map((item) => OfflineOperation.fromJson(item as Map<String, dynamic>))
      );
      _updateOperations();
    }
  }

  /// Save operations to storage
  Future<void> _saveOperations() async {
    await _cacheManager.put(
      _operationsKey,
      _operations.map((e) => e.toJson()).toList(),
    );
  }

  /// Setup connectivity listener
  void _setupConnectivityListener() {
    _connectivityManager.connectionStream.listen((state) {
      if (state == NetworkState.online) {
        processOperations();
      }
    });
  }

  /// Generate unique operation ID
  String _generateOperationId() => 
      '${DateTime.now().millisecondsSinceEpoch}_${_operations.length}';

  /// Update operations stream
  void _updateOperations() {
    if (!_operationsController.isClosed) {
      _operationsController.add(List.unmodifiable(_operations));
    }
  }

  /// Clear completed operations
  Future<void> clearCompletedOperations() async {
    _operations.removeWhere((op) => op.status == OfflineOperationStatus.completed);
    await _saveOperations();
    _updateOperations();
  }

  /// Get operations by status
  List<OfflineOperation> getOperationsByStatus(OfflineOperationStatus status) =>
      _operations.where((op) => op.status == status).toList();

  /// Dispose resources
  void dispose() {
    _operationsController.close();
  }
}