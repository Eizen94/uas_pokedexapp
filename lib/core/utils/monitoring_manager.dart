// lib/core/utils/monitoring_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import './connectivity_manager.dart';
import './request_manager.dart';
import '../constants/api_paths.dart';

/// Manages network monitoring, connection quality, and system metrics
class MonitoringManager {
  // Singleton with thread safety
  static final MonitoringManager _instance = MonitoringManager._internal();
  factory MonitoringManager() => _instance;
  MonitoringManager._internal();

  // Core components
  final Connectivity _connectivity = Connectivity();
  final _metrics = _MonitoringMetrics();

  // Stream controllers for status updates
  final _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();
  final _networkQualityController =
      StreamController<NetworkQuality>.broadcast();
  final _metricsController = StreamController<MonitoringMetrics>.broadcast();

  // Monitoring state management
  Timer? _monitorTimer;
  Timer? _metricsTimer;
  bool _isMonitoring = false;
  ConnectivityResult? _lastResult;
  DateTime? _lastCheckTime;
  int _consecutiveFailures = 0;
  bool _isDisposed = false;

  // Constants
  static const Duration _monitorInterval = Duration(seconds: 30);
  static const Duration _metricsInterval = Duration(minutes: 1);
  static const int _maxConsecutiveFailures = 3;
  static const Duration _timeout = Duration(seconds: 5);

  // Public getters
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;
  Stream<NetworkQuality> get networkQuality => _networkQualityController.stream;
  Stream<MonitoringMetrics> get metrics => _metricsController.stream;
  bool get isMonitoring => _isMonitoring;

  /// Start monitoring system
  Future<void> startMonitoring() async {
    if (_isMonitoring || _isDisposed) return;

    try {
      _isMonitoring = true;

      // Get initial connectivity status
      final initialResult =
          await _connectivity.checkConnectivity().timeout(_timeout);
      _lastResult = initialResult;
      await _updateConnectionStatus(initialResult);

      // Setup periodic monitoring
      _monitorTimer?.cancel();
      _monitorTimer = Timer.periodic(_monitorInterval, (_) {
        _checkConnectivity();
      });

      // Setup metrics collection
      _metricsTimer?.cancel();
      _metricsTimer = Timer.periodic(_metricsInterval, (_) {
        _updateMetrics();
      });

      if (kDebugMode) {
        print('✅ Monitoring started');
      }
    } catch (e) {
      _isMonitoring = false;
      if (kDebugMode) {
        print('❌ Error starting monitoring: $e');
      }
      rethrow;
    }
  }

  /// Stop monitoring system
  Future<void> stopMonitoring() async {
    _monitorTimer?.cancel();
    _metricsTimer?.cancel();
    _isMonitoring = false;

    if (kDebugMode) {
      print('⏹️ Monitoring stopped');
    }
  }

  /// Check current connectivity
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity().timeout(_timeout);

      _lastCheckTime = DateTime.now();
      await _updateConnectionStatus(result);
      _consecutiveFailures = 0;
    } catch (e) {
      _consecutiveFailures++;

      if (_consecutiveFailures >= _maxConsecutiveFailures) {
        await _handleConnectionFailure();
      }

      if (kDebugMode) {
        print('⚠️ Connectivity check failed: $e');
      }
    }
  }

  /// Update connection status
  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    if (result == _lastResult && !_needsQualityCheck(result)) return;

    _lastResult = result;
    final status = _getConnectionStatus(result);

    if (!_connectionStatusController.isClosed && !_isDisposed) {
      _connectionStatusController.add(status);
    }

    // Update metrics
    _metrics.updateConnectionStatus(status);
    await _updateMetrics();

    if (kDebugMode) {
      print('🔄 Connection status updated: $status');
    }
  }

  bool _needsQualityCheck(ConnectivityResult result) {
    return result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile;
  }

  /// Handle connection failure
  Future<void> _handleConnectionFailure() async {
    final status = ConnectionStatus.offline;

    if (!_connectionStatusController.isClosed && !_isDisposed) {
      _connectionStatusController.add(status);
    }

    // Update metrics
    _metrics.connectionFailures++;
    await _updateMetrics();

    if (kDebugMode) {
      print('❌ Connection failure detected');
    }
  }

  /// Update monitoring metrics
  Future<void> _updateMetrics() async {
    if (!_metricsController.isClosed && !_isDisposed) {
      final currentMetrics = MonitoringMetrics(
        uptime: _metrics.uptime,
        connectionFailures: _metrics.connectionFailures,
        lastCheckTime: _lastCheckTime,
        currentStatus: _getConnectionStatus(_lastResult),
      );
      _metricsController.add(currentMetrics);
    }
  }

  /// Convert to connection status
  ConnectionStatus _getConnectionStatus(ConnectivityResult? result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return ConnectionStatus.wifi;
      case ConnectivityResult.mobile:
        return ConnectionStatus.cellular;
      case ConnectivityResult.ethernet:
        return ConnectionStatus.ethernet;
      case ConnectivityResult.bluetooth:
        return ConnectionStatus.bluetooth;
      case ConnectivityResult.vpn:
        return ConnectionStatus.vpn;
      case ConnectivityResult.none:
        return ConnectionStatus.offline;
      default:
        return ConnectionStatus.unknown;
    }
  }

  /// Get time since last check
  Duration? getTimeSinceLastCheck() {
    if (_lastCheckTime == null) return null;
    return DateTime.now().difference(_lastCheckTime!);
  }

  /// Reset monitoring metrics
  void resetMetrics() {
    _metrics.reset();
    _updateMetrics();
  }

  /// Cleanup resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    await stopMonitoring();

    await Future.wait([
      _connectionStatusController.close(),
      _networkQualityController.close(),
      _metricsController.close(),
    ]);

    if (kDebugMode) {
      print('🧹 MonitoringManager disposed');
    }
  }
}

/// Internal metrics tracking
class _MonitoringMetrics {
  final DateTime _startTime = DateTime.now();
  int connectionFailures = 0;

  Duration get uptime => DateTime.now().difference(_startTime);

  void updateConnectionStatus(ConnectionStatus status) {
    // Additional metric tracking can be added here
  }

  void reset() {
    connectionFailures = 0;
  }
}

/// Public metrics data
class MonitoringMetrics {
  final Duration uptime;
  final int connectionFailures;
  final DateTime? lastCheckTime;
  final ConnectionStatus currentStatus;

  MonitoringMetrics({
    required this.uptime,
    required this.connectionFailures,
    required this.lastCheckTime,
    required this.currentStatus,
  });

  @override
  String toString() =>
      'MonitoringMetrics(uptime: $uptime, failures: $connectionFailures, status: $currentStatus)';
}

/// Connection status enum matching ConnectivityManager
enum ConnectionStatus {
  wifi('WiFi'),
  cellular('Cellular'),
  ethernet('Ethernet'),
  bluetooth('Bluetooth'),
  vpn('VPN'),
  offline('Offline'),
  unknown('Unknown');

  final String value;
  const ConnectionStatus(this.value);

  bool get isOnline =>
      this != ConnectionStatus.offline && this != ConnectionStatus.unknown;

  bool get isHighSpeed =>
      this == ConnectionStatus.wifi || this == ConnectionStatus.ethernet;

  bool get isLowSpeed =>
      this == ConnectionStatus.cellular || this == ConnectionStatus.bluetooth;

  bool get isMobile => this == ConnectionStatus.cellular;

  @override
  String toString() => value;
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

  bool get isGoodEnough =>
      this == NetworkQuality.excellent || this == NetworkQuality.good;

  bool get needsImprovement =>
      this == NetworkQuality.fair || this == NetworkQuality.poor;

  bool get isUnusable => this == NetworkQuality.poor;

  @override
  String toString() => value;
}
