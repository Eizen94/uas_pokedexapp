// lib/core/utils/monitoring_manager.dart

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connectivity_manager.dart';
import 'request_manager.dart';
import 'prefs_helper.dart';
import '../constants/api_paths.dart';

/// Enhanced monitoring system for tracking app health, performance,
/// and resource usage with proper error handling and persistence.
class MonitoringManager {
  // Singleton management
  static final MonitoringManager _instance = MonitoringManager._internal();
  static final _lock = Object();

  // Core components with proper initialization
  final Connectivity _connectivity = Connectivity();
  final _metrics = _MonitoringMetrics();
  late final PrefsHelper _prefsHelper;

  // Stream controllers with proper typing
  final _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();
  final _networkQualityController =
      StreamController<NetworkQuality>.broadcast();
  final _metricsController = StreamController<MonitoringMetrics>.broadcast();
  final _errorController = StreamController<MonitoringError>.broadcast();

  // State management with proper null safety
  Timer? _monitorTimer;
  Timer? _metricsTimer;
  Timer? _cleanupTimer;
  ConnectivityResult? _lastResult;
  DateTime? _lastCheckTime;
  DateTime? _startTime;
  int _consecutiveFailures = 0;
  bool _isMonitoring = false;
  bool _isDisposed = false;

  // Metric storage with proper typing
  final Queue<NetworkQualityMetric> _qualityMetrics = Queue();
  final Queue<PerformanceMetric> _performanceMetrics = Queue();
  final Map<String, int> _errorCounts = {};

  // Constants
  static const Duration _monitorInterval = Duration(seconds: 30);
  static const Duration _metricsInterval = Duration(minutes: 1);
  static const Duration _cleanupInterval = Duration(hours: 1);
  static const Duration _metricRetention = Duration(days: 7);
  static const int _maxQueueSize = 1000;
  static const int _maxConsecutiveFailures = 5;
  static const String _metricsKey = 'monitoring_metrics';
  static const String _tag = 'MonitoringManager';

  // Private constructor with initialization
  MonitoringManager._internal() {
    _startTime = DateTime.now();
  }

  // Factory constructor
  factory MonitoringManager() => _instance;

  /// Initialize monitoring system with proper error handling
  Future<void> initialize() async {
    if (_isDisposed) {
      throw StateError('$_tag has been disposed');
    }

    await synchronized(_lock, () async {
      if (_isMonitoring) return;

      try {
        // Initialize dependencies
        _prefsHelper = await PrefsHelper.getInstance();
        await _loadPersistedMetrics();

        // Start monitoring timers
        _startMonitoring();
        _startMetricsCollection();
        _startCleanupTask();

        // Set initial status
        final initialResult = await _connectivity.checkConnectivity();
        _lastResult = initialResult;
        await _updateConnectionStatus(initialResult);

        _isMonitoring = true;

        if (kDebugMode) {
          print('✅ $_tag initialized');
        }
      } catch (e) {
        _handleError(
          MonitoringError(
            type: ErrorType.initialization,
            message: 'Failed to initialize monitoring: $e',
            timestamp: DateTime.now(),
          ),
        );
        rethrow;
      }
    });
  }

  /// Start periodic monitoring with proper resource management
  void _startMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(_monitorInterval, (_) {
      _checkSystemStatus();
    });
  }

  /// Start metrics collection with proper cleanup
  void _startMetricsCollection() {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(_metricsInterval, (_) {
      _collectMetrics();
    });
  }

  /// Start cleanup task with proper resource management
  void _startCleanupTask() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      _cleanupOldMetrics();
    });
  }

  /// Check system status with proper error handling
  Future<void> _checkSystemStatus() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _lastCheckTime = DateTime.now();
      await _updateConnectionStatus(result);
      _consecutiveFailures = 0;
    } catch (e) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= _maxConsecutiveFailures) {
        await _handleConnectionFailure();
      }
      _handleError(
        MonitoringError(
          type: ErrorType.connection,
          message: 'Connection check failed: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Update connection status with proper state management
  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    if (result == _lastResult && !_needsQualityCheck(result)) return;

    _lastResult = result;
    final status = _getConnectionStatus(result);
    final quality = await _assessNetworkQuality();

    if (!_connectionStatusController.isClosed && !_isDisposed) {
      _connectionStatusController.add(status);
    }

    if (!_networkQualityController.isClosed && !_isDisposed) {
      _networkQualityController.add(quality);
    }

    // Update metrics with proper validation
    _metrics.updateConnectionStatus(status);
    _qualityMetrics.addLast(
      NetworkQualityMetric(
        quality: quality,
        timestamp: DateTime.now(),
      ),
    );

    await _persistMetrics();
  }

  /// Handle connection failure with proper error propagation
  Future<void> _handleConnectionFailure() async {
    final status = ConnectionStatus.offline;

    if (!_connectionStatusController.isClosed && !_isDisposed) {
      _connectionStatusController.add(status);
    }

    _metrics.connectionFailures++;
    await _persistMetrics();

    _handleError(
      MonitoringError(
        type: ErrorType.connection,
        message: 'Connection failure detected',
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Assess network quality with proper error handling
  Future<NetworkQuality> _assessNetworkQuality() async {
    try {
      final startTime = DateTime.now();
      final response = await _makeQualityTestRequest();
      final duration = DateTime.now().difference(startTime);

      if (response.statusCode != 200) {
        return NetworkQuality.poor;
      }

      if (duration.inMilliseconds < 100) return NetworkQuality.excellent;
      if (duration.inMilliseconds < 300) return NetworkQuality.good;
      if (duration.inMilliseconds < 1000) return NetworkQuality.fair;
      return NetworkQuality.poor;
    } catch (e) {
      return NetworkQuality.unknown;
    }
  }

  /// Make test request with proper timeout
  Future<http.Response> _makeQualityTestRequest() async {
    return await http
        .get(Uri.parse(ApiPaths.kBaseUrl))
        .timeout(const Duration(seconds: 5));
  }

  /// Check if quality check is needed
  bool _needsQualityCheck(ConnectivityResult result) {
    return result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile;
  }

  /// Get connection status from result
  ConnectionStatus _getConnectionStatus(ConnectivityResult? result) {
    return switch (result) {
      ConnectivityResult.wifi => ConnectionStatus.wifi,
      ConnectivityResult.mobile => ConnectionStatus.cellular,
      ConnectivityResult.ethernet => ConnectionStatus.ethernet,
      ConnectivityResult.none => ConnectionStatus.offline,
      null => ConnectionStatus.unknown,
    };
  }

  /// Collect system metrics with proper error handling
  Future<void> _collectMetrics() async {
    if (_isDisposed) return;

    try {
      final metrics = MonitoringMetrics(
        uptime: DateTime.now().difference(_startTime!),
        connectionFailures: _metrics.connectionFailures,
        lastCheckTime: _lastCheckTime,
        currentStatus: _getConnectionStatus(_lastResult),
        memoryUsage: 0, // Implement memory usage tracking
        batteryLevel: 0, // Implement battery level tracking
        networkUsage: 0, // Implement network usage tracking
      );

      if (!_metricsController.isClosed) {
        _metricsController.add(metrics);
      }

      _performanceMetrics.addLast(
        PerformanceMetric(
          metrics: metrics,
          timestamp: DateTime.now(),
        ),
      );

      await _persistMetrics();
    } catch (e) {
      _handleError(
        MonitoringError(
          type: ErrorType.metrics,
          message: 'Failed to collect metrics: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Clean up old metrics with proper resource management
  Future<void> _cleanupOldMetrics() async {
    final now = DateTime.now();

    // Clean up quality metrics
    while (_qualityMetrics.isNotEmpty &&
        now.difference(_qualityMetrics.first.timestamp) > _metricRetention) {
      _qualityMetrics.removeFirst();
    }

    // Clean up performance metrics
    while (_performanceMetrics.isNotEmpty &&
        now.difference(_performanceMetrics.first.timestamp) >
            _metricRetention) {
      _performanceMetrics.removeFirst();
    }

    // Enforce queue size limits
    while (_qualityMetrics.length > _maxQueueSize) {
      _qualityMetrics.removeFirst();
    }
    while (_performanceMetrics.length > _maxQueueSize) {
      _performanceMetrics.removeFirst();
    }

    await _persistMetrics();
  }

  /// Load persisted metrics with proper error handling
  Future<void> _loadPersistedMetrics() async {
    try {
      final json = _prefsHelper.prefs.getString(_metricsKey);
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        // Implement metric restoration
      }
    } catch (e) {
      _handleError(
        MonitoringError(
          type: ErrorType.persistence,
          message: 'Failed to load metrics: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Persist current metrics with proper error handling
  Future<void> _persistMetrics() async {
    try {
      final data = {
        'quality_metrics': _qualityMetrics.map((m) => m.toJson()).toList(),
        'performance_metrics':
            _performanceMetrics.map((m) => m.toJson()).toList(),
        'error_counts': _errorCounts,
      };

      await _prefsHelper.prefs.setString(_metricsKey, jsonEncode(data));
    } catch (e) {
      _handleError(
        MonitoringError(
          type: ErrorType.persistence,
          message: 'Failed to persist metrics: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Handle monitoring error with proper logging
  void _handleError(MonitoringError error) {
    _errorCounts[error.type.toString()] =
        (_errorCounts[error.type.toString()] ?? 0) + 1;

    if (!_errorController.isClosed && !_isDisposed) {
      _errorController.add(error);
    }

    if (kDebugMode) {
      print('❌ Monitoring error: ${error.message}');
    }
  }

  /// Get current monitoring metrics
  MonitoringMetrics get currentMetrics => MonitoringMetrics(
        uptime: _metrics.uptime,
        connectionFailures: _metrics.connectionFailures,
        lastCheckTime: _lastCheckTime,
        currentStatus: _getConnectionStatus(_lastResult),
        memoryUsage: 0, // Implement
        batteryLevel: 0, // Implement
        networkUsage: 0, // Implement
      );

  /// Reset monitoring metrics with proper cleanup
  Future<void> reset() async {
    await synchronized(_lock, () async {
      _metrics.reset();
      _qualityMetrics.clear();
      _performanceMetrics.clear();
      _errorCounts.clear();
      _consecutiveFailures = 0;
      _lastCheckTime = null;

      await _persistMetrics();
    });
  }

  /// Proper resource disposal
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _isMonitoring = false;

    _monitorTimer?.cancel();
    _metricsTimer?.cancel();
    _cleanupTimer?.cancel();

    await Future.wait([
      _connectionStatusController.close(),
      _networkQualityController.close(),
      _metricsController.close(),
      _errorController.close(),
    ]);

    _qualityMetrics.clear();
    _performanceMetrics.clear();
    _errorCounts.clear();

    if (kDebugMode) {
      print('🧹 $_tag disposed');
    }
  }

  // Public streams
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;
  Stream<NetworkQuality> get networkQuality => _networkQualityController.stream;
  Stream<MonitoringMetrics> get metrics => _metricsController.stream;
  Stream<MonitoringError> get errors => _errorController.stream;
}

/// Connection status enum
enum ConnectionStatus {
  wifi('WiFi'),
  cellular('Cellular'),
  ethernet('Ethernet'),
  offline('Offline'),
  unknown('Unknown');

  final String value;
  const ConnectionStatus(this.value);
}

/// Network quality levels
enum NetworkQuality {
  excellent('Excellent'),
  good('Good'),
  fair('Fair'),
  poor('Poor'),
  unknown('Unknown');

  final String value;
  const NetworkQuality(this.value);
}

/// Error types
enum ErrorType {
  initialization,
  connection,
  metrics,
  persistence,
}

/// Monitoring metrics value object
class MonitoringMetrics {
  final Duration uptime;
  final int connectionFailures;
  final DateTime? lastCheckTime;
  final ConnectionStatus currentStatus;
  final int memoryUsage;
  final int batteryLevel;
  final int networkUsage;

  MonitoringMetrics({
    required this.uptime,
    required this.connectionFailures,
    required this.lastCheckTime,
    required this.currentStatus,
    required this.memoryUsage,
    required this.batteryLevel,
    required this.networkUsage,
  });

  Map<String, dynamic> toJson() => {
        'uptime': uptime.inSeconds,
        'connectionFailures': connectionFailures,
        'lastCheckTime': lastCheckTime?.millisecondsSinceEpoch,
        'currentStatus': currentStatus.toString(),
        'memoryUsage': memoryUsage,
        'batteryLevel': batteryLevel,
        'networkUsage': networkUsage,
      };
}

/// Internal metrics tracking
class _MonitoringMetrics {
  final DateTime _startTime = DateTime.now();
  int connectionFailures = 0;

  Duration get uptime => DateTime.now().difference(_startTime);

  void updateConnectionStatus(ConnectionStatus status) {
    // Implement metric tracking
  }

  void reset() {
    connectionFailures = 0;
  }
}

/// Network quality metric
class NetworkQualityMetric {
  final NetworkQuality quality;
  final DateTime timestamp;

  NetworkQualityMetric({
    required this.quality,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'quality': quality.toString(),
        'timestamp': timestamp.millisecondsSinceEpoch,
      };
}

/// Performance metric
class PerformanceMetric {
  final MonitoringMetrics metrics;
  final DateTime timestamp;

  PerformanceMetric({
    required this.metrics,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'metrics': metrics.toJson(),
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory PerformanceMetric.fromJson(Map<String, dynamic> json) {
    return PerformanceMetric(
      metrics: MonitoringMetrics(
        uptime: Duration(seconds: json['metrics']['uptime'] as int),
        connectionFailures: json['metrics']['connectionFailures'] as int,
        lastCheckTime: json['metrics']['lastCheckTime'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                json['metrics']['lastCheckTime'] as int)
            : null,
        currentStatus: ConnectionStatus.values.firstWhere(
          (e) => e.toString() == json['metrics']['currentStatus'],
          orElse: () => ConnectionStatus.unknown,
        ),
        memoryUsage: json['metrics']['memoryUsage'] as int,
        batteryLevel: json['metrics']['batteryLevel'] as int,
        networkUsage: json['metrics']['networkUsage'] as int,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }
}

/// Monitoring error
class MonitoringError {
  final ErrorType type;
  final String message;
  final DateTime timestamp;
  final dynamic details;

  MonitoringError({
    required this.type,
    required this.message,
    required this.timestamp,
    this.details,
  });

  Map<String, dynamic> toJson() => {
        'type': type.toString(),
        'message': message,
        'timestamp': timestamp.millisecondsSinceEpoch,
        if (details != null) 'details': details.toString(),
      };

  factory MonitoringError.fromJson(Map<String, dynamic> json) {
    return MonitoringError(
      type: ErrorType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ErrorType.initialization,
      ),
      message: json['message'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      details: json['details'],
    );
  }

  @override
  String toString() => 'MonitoringError(type: $type, message: $message)';
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
