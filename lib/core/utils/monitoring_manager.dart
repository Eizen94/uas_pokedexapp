// lib/core/utils/monitoring_manager.dart

/// Monitoring manager to track app performance and stability.
/// Handles performance metrics, error tracking, and analytics.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:rxdart/subjects.dart';

/// Log level for monitoring
enum LogLevel {
  /// Debug level logs
  debug,

  /// Info level logs
  info,

  /// Warning level logs
  warning,

  /// Error level logs
  error,

  /// Critical level logs
  critical
}

/// Performance metric types
enum MetricType {
  /// API response time
  apiResponse,

  /// Frame render time
  frameTime,

  /// Memory usage
  memory,

  /// Battery impact
  battery,

  /// Cache usage
  cache
}

/// Monitoring manager for app performance and stability
class MonitoringManager {
  static final MonitoringManager _instance = MonitoringManager._internal();

  /// Singleton instance
  factory MonitoringManager() => _instance;

  MonitoringManager._internal() {
    _startPeriodicMetricsCollection();
  }

  // Stream controllers
  final BehaviorSubject<Map<MetricType, double>> _metricsController =
      BehaviorSubject<Map<MetricType, double>>.seeded({});

  final BehaviorSubject<List<LogEntry>> _logsController =
      BehaviorSubject<List<LogEntry>>.seeded([]);

  // Internal state
  final List<LogEntry> _logs = [];
  Timer? _metricsTimer;
  static const int _maxLogRetention = 1000;
  static const Duration _metricInterval = Duration(minutes: 1);

  /// Stream of performance metrics
  Stream<Map<MetricType, double>> get metricsStream =>
      _metricsController.stream;

  /// Stream of application logs
  Stream<List<LogEntry>> get logsStream => _logsController.stream;

  /// Log API response
  void logApiResponse({
    required String requestId,
    required int statusCode,
    required String url,
    String? error,
  }) {
    final entry = LogEntry(
      level: statusCode >= 400 ? LogLevel.error : LogLevel.info,
      message: 'API Response: $statusCode - $url',
      timestamp: DateTime.now(),
      data: {
        'requestId': requestId,
        'statusCode': statusCode,
        'url': url,
        if (error != null) 'error': error,
      },
    );

    _addLog(entry);
    _trackMetric(MetricType.apiResponse, statusCode >= 400 ? 1.0 : 0.0);
  }

  /// Log performance metric
  void logPerformanceMetric({
    required MetricType type,
    required double value,
    Map<String, dynamic>? additionalData,
  }) {
    final entry = LogEntry(
      level: LogLevel.info,
      message: 'Performance Metric: ${type.name} - $value',
      timestamp: DateTime.now(),
      data: {
        'type': type.name,
        'value': value,
        if (additionalData != null) ...additionalData,
      },
    );

    _addLog(entry);
    _trackMetric(type, value);
  }

  /// Log error occurrence
  void logError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    final entry = LogEntry(
      level: LogLevel.error,
      message: message,
      timestamp: DateTime.now(),
      data: {
        if (error != null) 'error': error.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        if (additionalData != null) ...additionalData,
      },
    );

    _addLog(entry);
  }

  /// Add log entry
  void _addLog(LogEntry entry) {
    _logs.add(entry);

    // Maintain log size limit
    while (_logs.length > _maxLogRetention) {
      _logs.removeAt(0);
    }

    if (!_logsController.isClosed) {
      _logsController.add(List.unmodifiable(_logs));
    }
  }

  /// Track performance metric
  void _trackMetric(MetricType type, double value) {
    if (!_metricsController.isClosed) {
      final currentMetrics =
          Map<MetricType, double>.from(_metricsController.value);
      currentMetrics[type] = value;
      _metricsController.add(currentMetrics);
    }
  }

  /// Start periodic metrics collection
  void _startPeriodicMetricsCollection() {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(_metricInterval, (_) {
      _collectMetrics();
    });
  }

  /// Collect current metrics
  void _collectMetrics() {
    // Frame time using utility
    final frameTime = PerformanceUtils.getCurrentFrameTime();
    logPerformanceMetric(type: MetricType.frameTime, value: frameTime);

    // Memory metrics (debug only)
    if (kDebugMode) {
      final memoryUsage = PerformanceUtils.getApproximateMemoryUsage();
      logPerformanceMetric(type: MetricType.memory, value: memoryUsage);
    }
  }

  /// Get filtered logs
  List<LogEntry> getFilteredLogs({
    LogLevel? level,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return _logs.where((log) {
      if (level != null && log.level != level) return false;
      if (startTime != null && log.timestamp.isBefore(startTime)) return false;
      if (endTime != null && log.timestamp.isAfter(endTime)) return false;
      return true;
    }).toList();
  }

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
    if (!_logsController.isClosed) {
      _logsController.add([]);
    }
  }

  /// Dispose resources
  void dispose() {
    _metricsTimer?.cancel();
    _metricsController.close();
    _logsController.close();
  }
}

/// Log entry class
class LogEntry {
  /// Log level
  final LogLevel level;

  /// Log message
  final String message;

  /// Timestamp
  final DateTime timestamp;

  /// Additional data
  final Map<String, dynamic> data;

  const LogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    this.data = const {},
  });

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}] ${level.name.toUpperCase()}: $message';
}
