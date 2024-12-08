// lib/core/utils/offline_operation.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Base class for offline operations with retry and persistence capabilities
abstract class OfflineOperation {
  final String id;
  final OperationPriority priority;
  final Duration timeout;
  DateTime timestamp;
  int retryCount;
  OperationStatus status;

  OfflineOperation({
    required this.id,
    this.priority = OperationPriority.normal,
    this.timeout = const Duration(minutes: 1),
  })  : timestamp = DateTime.now(),
        retryCount = 0,
        status = OperationStatus.pending;

  /// Execute the operation
  Future<void> execute();

  /// Check if operation can be retried
  bool canRetry() => retryCount < maxRetries && !isExpired();

  /// Check if operation is expired
  bool isExpired() {
    return DateTime.now().difference(timestamp) > maxLifetime;
  }

  /// Convert operation to storable format
  Map<String, dynamic> toJson();

  /// Create operation from stored format
  static OfflineOperation? fromJson(Map<String, dynamic> json);

  /// Maximum number of retry attempts
  static const int maxRetries = 3;

  /// Maximum lifetime of an operation
  static const Duration maxLifetime = Duration(hours: 24);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineOperation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Handles persistence of offline operations
class OfflineOperationStorage {
  static const String _storageKey = 'offline_operations';
  late final SharedPreferences _prefs;
  bool _initialized = false;

  /// Initialize storage
  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Save operation to persistent storage
  Future<void> saveOperation(OfflineOperation operation) async {
    if (!_initialized) await initialize();

    try {
      final operations = await _loadOperations();
      operations[operation.id] = operation.toJson();
      await _saveOperations(operations);

      if (kDebugMode) {
        print('✅ Saved offline operation: ${operation.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving offline operation: $e');
      }
      rethrow;
    }
  }

  /// Remove operation from storage
  Future<void> removeOperation(String id) async {
    if (!_initialized) await initialize();

    try {
      final operations = await _loadOperations();
      operations.remove(id);
      await _saveOperations(operations);

      if (kDebugMode) {
        print('✅ Removed offline operation: $id');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removing offline operation: $e');
      }
      rethrow;
    }
  }

  /// Load all stored operations
  Future<List<OfflineOperation>> loadAllOperations() async {
    if (!_initialized) await initialize();

    try {
      final operations = await _loadOperations();
      return operations.values
          .map((json) => OfflineOperation.fromJson(json))
          .where((op) => op != null)
          .cast<OfflineOperation>()
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading offline operations: $e');
      }
      return [];
    }
  }

  /// Clear all stored operations
  Future<void> clearAllOperations() async {
    if (!_initialized) await initialize();

    try {
      await _prefs.remove(_storageKey);
      if (kDebugMode) {
        print('✅ Cleared all offline operations');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing offline operations: $e');
      }
      rethrow;
    }
  }

  /// Load operations from storage
  Future<Map<String, dynamic>> _loadOperations() async {
    final String? data = _prefs.getString(_storageKey);
    if (data == null) return {};
    
    try {
      return Map<String, dynamic>.from(
        const JsonDecoder().convert(data) as Map);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error parsing stored operations: $e');
      }
      return {};
    }
  }

  /// Save operations to storage
  Future<void> _saveOperations(Map<String, dynamic> operations) async {
    final data = const JsonEncoder().convert(operations);
    await _prefs.setString(_storageKey, data);
  }
}

/// Operation executor with retry mechanism
class OfflineOperationExecutor {
  final Duration _retryDelay;
  final int _maxConcurrent;
  
  OfflineOperationExecutor({
    Duration? retryDelay,
    int? maxConcurrent,
  })  : _retryDelay = retryDelay ?? const Duration(seconds: 5),
        _maxConcurrent = maxConcurrent ?? 3;

  int _activeOperations = 0;

  /// Execute operation with retry
  Future<void> execute(OfflineOperation operation) async {
    if (_activeOperations >= _maxConcurrent) {
      throw const ConcurrencyLimitException();
    }

    try {
      _activeOperations++;
      operation.status = OperationStatus.inProgress;

      if (kDebugMode) {
        print('🚀 Executing operation: ${operation.id} (Attempt: ${operation.retryCount + 1})');
      }

      await operation.execute().timeout(operation.timeout);
      operation.status = OperationStatus.completed;

      if (kDebugMode) {
        print('✅ Operation completed: ${operation.id}');
      }
    } catch (e) {
      operation.status = OperationStatus.failed;
      operation.retryCount++;

      if (kDebugMode) {
        print('❌ Operation failed: ${operation.id} - $e');
      }

      if (operation.canRetry()) {
        await Future.delayed(_getRetryDelay(operation.retryCount));
        await execute(operation);
      } else {
        rethrow;
      }
    } finally {
      _activeOperations--;
    }
  }

  /// Calculate retry delay with exponential backoff
  Duration _getRetryDelay(int retryCount) {
    return _retryDelay * (1 << retryCount);
  }
}

/// Operation priority levels
enum OperationPriority {
  high,
  normal,
  low;

  bool get isHigh => this == OperationPriority.high;
  bool get isNormal => this == OperationPriority.normal;
  bool get isLow => this == OperationPriority.low;
}

/// Operation status
enum OperationStatus {
  pending('Pending'),
  inProgress('In Progress'),
  completed('Completed'),
  failed('Failed');

  final String value;
  const OperationStatus(this.value);

  bool get isPending => this == OperationStatus.pending;
  bool get isInProgress => this == OperationStatus.inProgress;
  bool get isCompleted => this == OperationStatus.completed;
  bool get isFailed => this == OperationStatus.failed;

  @override
  String toString() => value;
}

/// Custom exceptions
class ConcurrencyLimitException implements Exception {
  const ConcurrencyLimitException();

  @override
  String toString() => 'Maximum concurrent operations limit reached';
}