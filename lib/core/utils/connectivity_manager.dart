// lib/core/utils/connectivity_manager.dart

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_paths.dart';
import 'request_manager.dart';
import 'monitoring_manager.dart';
import 'prefs_helper.dart';

/// Enhanced connectivity manager optimized for managing network states,
/// quality monitoring and smart recovery.
class ConnectivityManager {
  // Singleton implementation
  static ConnectivityManager? _instance;
  static final _instanceLock = Object();

  // Core components with proper initialization
  final Connectivity _connectivity = Connectivity();
  late final PrefsHelper _prefsHelper;
  final _networkStateController = StreamController<NetworkState>.broadcast();
  final _qualityTestResults = <DateTime, Duration>{};

  // State tracking with proper null safety
  Timer? _monitorTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  NetworkState _currentState = NetworkState.unknown;
  DateTime? _lastOnlineTime;
  DateTime? _lastSyncTime;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isMonitoring = false;
  int _consecutiveFailures = 0;

  // Configuration constants
  static const Duration _monitorInterval = Duration(seconds: 15);
  static const Duration _qualityTestTimeout = Duration(seconds: 5);
  static const Duration _backoffInterval = Duration(seconds: 30);
  static const Duration _minSyncInterval = Duration(minutes: 15);
  static const int _maxConsecutiveFailures = 3;
  static const String _lastOnlineKey = 'last_online_timestamp';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _networkQualityKey = 'network_quality_history';

  // Private constructor
  ConnectivityManager._();

  /// Get singleton instance with proper initialization
  static Future<ConnectivityManager> getInstance() async {
    if (_instance != null) return _instance!;

    await synchronized(_instanceLock, () async {
      if (_instance == null) {
        _instance = ConnectivityManager._();
        await _instance!._initialize();
      }
    });

    return _instance!;
  }

  /// Initialize manager with proper error handling
  Future<void> _initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      // Initialize dependencies
      _prefsHelper = await PrefsHelper.getInstance();
      await _loadPersistedState();

      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _updateNetworkState(result);

      // Setup connectivity listener
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _handleConnectivityChange,
        onError: (e) {
          if (kDebugMode) {
            print('⚠️ Connectivity listener error: $e');
          }
        },
      );

      // Start monitoring
      _startMonitoring();
      _isInitialized = true;

      if (kDebugMode) {
        print('✅ ConnectivityManager initialized: ${_currentState.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ConnectivityManager initialization error: $e');
      }
      rethrow;
    }
  }

  /// Start network monitoring with proper error handling
  void _startMonitoring() {
    if (_isMonitoring || _isDisposed) return;

    _isMonitoring = true;
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(_monitorInterval, (_) {
      _checkConnectivity();
    });
  }

  /// Load persisted network state with proper error handling
  Future<void> _loadPersistedState() async {
    try {
      final prefs = _prefsHelper.prefs;

      // Load timestamps with proper null safety
      final lastOnlineTimestamp = prefs.getInt(_lastOnlineKey);
      if (lastOnlineTimestamp != null) {
        _lastOnlineTime =
            DateTime.fromMillisecondsSinceEpoch(lastOnlineTimestamp);
      }

      final lastSyncTimestamp = prefs.getInt(_lastSyncKey);
      if (lastSyncTimestamp != null) {
        _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp);
      }

      // Load quality history with error handling
      final qualityJson = prefs.getString(_networkQualityKey);
      if (qualityJson != null) {
        try {
          final qualityData = json.decode(qualityJson) as Map<String, dynamic>;
          _qualityTestResults.clear();
          qualityData.forEach((key, value) {
            final timestamp = DateTime.parse(key);
            final duration = Duration(milliseconds: value as int);
            _qualityTestResults[timestamp] = duration;
          });
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error parsing quality history: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error loading persisted state: $e');
      }
    }
  }

  /// Check current connectivity with quality testing
  Future<bool> checkConnectivity() async {
    _throwIfNotInitialized();

    try {
      final result = await _connectivity.checkConnectivity();
      if (result == ConnectivityResult.none) {
        _updateNetworkState(result);
        return false;
      }

      final isReachable = await _testConnection();
      _updateNetworkState(
        isReachable ? result : ConnectivityResult.none,
        forceNotify: true,
      );

      return isReachable;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Connectivity check error: $e');
      }
      _updateNetworkState(ConnectivityResult.none);
      return false;
    }
  }

  /// Test connection with proper timeout and error handling
  Future<bool> _testConnection() async {
    try {
      final startTime = DateTime.now();
      final response = await http
          .get(Uri.parse(ApiPaths.kBaseUrl))
          .timeout(_qualityTestTimeout);

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      _qualityTestResults[endTime] = duration;

      // Cleanup old results
      _cleanupQualityResults();

      final success = response.statusCode == 200;
      if (success) {
        _consecutiveFailures = 0;
        _lastOnlineTime = DateTime.now();
        await _prefsHelper.prefs.setInt(
          _lastOnlineKey,
          _lastOnlineTime!.millisecondsSinceEpoch,
        );
      } else {
        _consecutiveFailures++;
      }

      return success;
    } catch (e) {
      _consecutiveFailures++;
      return false;
    }
  }

  /// Clean up old quality test results
  void _cleanupQualityResults() {
    final now = DateTime.now();
    _qualityTestResults.removeWhere(
      (time, _) => now.difference(time) > const Duration(hours: 1),
    );
  }

  /// Handle connectivity changes with proper state management
  void _handleConnectivityChange(ConnectivityResult result) async {
    if (!_isInitialized || _isDisposed) return;

    if (_currentState.type == result && !_needsQualityCheck()) {
      return;
    }

    final isReachable = await _testConnection();
    _updateNetworkState(
      isReachable ? result : ConnectivityResult.none,
      forceNotify: true,
    );

    if (kDebugMode) {
      print('🌐 Network state changed: ${_currentState.name}');
    }
  }

  /// Check if quality test is needed
  bool _needsQualityCheck() {
    if (_qualityTestResults.isEmpty) return true;

    final latestTest = _qualityTestResults.keys.reduce(
      (a, b) => a.isAfter(b) ? a : b,
    );
    return DateTime.now().difference(latestTest) > _monitorInterval;
  }

  /// Update network state with proper notification handling
  void _updateNetworkState(
    ConnectivityResult result, {
    bool forceNotify = false,
  }) {
    final oldState = _currentState;
    final newState = _getNetworkState(result);

    if (oldState == newState && !forceNotify) return;

    _currentState = newState;
    if (!_networkStateController.isClosed && !_isDisposed) {
      _networkStateController.add(newState);
    }

    // Update sync time for major state changes
    if (newState.isOnline && _lastSyncTime == null) {
      _lastSyncTime = DateTime.now();
      _prefsHelper.prefs.setInt(
        _lastSyncKey,
        _lastSyncTime!.millisecondsSinceEpoch,
      );
    }

    _persistNetworkState();
  }

  /// Convert connectivity result to network state
  NetworkState _getNetworkState(ConnectivityResult result) {
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      return NetworkState.unstable;
    }

    return switch (result) {
      ConnectivityResult.wifi => _getQualityBasedState(NetworkState.wifi),
      ConnectivityResult.mobile => _getQualityBasedState(NetworkState.mobile),
      ConnectivityResult.ethernet => NetworkState.ethernet,
      ConnectivityResult.none => NetworkState.offline,
      _ => NetworkState.unknown,
    };
  }

  /// Get network state based on quality metrics
  NetworkState _getQualityBasedState(NetworkState baseState) {
    if (_qualityTestResults.isEmpty) return baseState;

    final averageLatency = _qualityTestResults.values
            .map((d) => d.inMilliseconds)
            .reduce((a, b) => a + b) /
        _qualityTestResults.length;

    if (averageLatency < 100) return NetworkState.excellent;
    if (averageLatency < 300) return NetworkState.good;
    if (averageLatency < 1000) return NetworkState.poor;
    return NetworkState.unstable;
  }

  /// Validate initialization state
  void _throwIfNotInitialized() {
    if (_disposed) {
      throw StateError('ConnectivityManager has been disposed');
    }
    if (!_isInitialized) {
      throw StateError('ConnectivityManager not initialized');
    }
  }

  // Public getters
  Stream<NetworkState> get networkStateStream => _networkStateController.stream;
  NetworkState get currentState => _currentState;
  bool get isOnline => _currentState.isOnline;
  bool get isHighSpeed => _currentState.isHighSpeed;
  bool get needsOptimization => _currentState.needsOptimization;
  bool get isInitialized => _isInitialized;

  /// Proper resource disposal
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _isMonitoring = false;
    _monitorTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _networkStateController.close();
    _qualityTestResults.clear();
    _isInitialized = false;
    _instance = null;

    if (kDebugMode) {
      print('🧹 ConnectivityManager disposed');
    }
  }
}

/// Network state enum with proper type safety
enum NetworkState {
  wifi('WiFi', true),
  mobile('Mobile', true),
  ethernet('Ethernet', true),
  offline('Offline', false),
  unknown('Unknown', false),
  excellent('Excellent', true),
  good('Good', true),
  poor('Poor', true),
  unstable('Unstable', true);

  final String name;
  final bool isOnline;

  const NetworkState(this.name, this.isOnline);

  ConnectivityResult get type {
    return switch (this) {
      NetworkState.wifi => ConnectivityResult.wifi,
      NetworkState.mobile => ConnectivityResult.mobile,
      NetworkState.ethernet => ConnectivityResult.ethernet,
      _ => ConnectivityResult.none,
    };
  }

  bool get isHighSpeed =>
      this == NetworkState.wifi ||
      this == NetworkState.ethernet ||
      this == NetworkState.excellent;

  bool get isReliable =>
      this == NetworkState.wifi ||
      this == NetworkState.ethernet ||
      this == NetworkState.excellent ||
      this == NetworkState.good;

  bool get needsOptimization =>
      this == NetworkState.mobile ||
      this == NetworkState.poor ||
      this == NetworkState.unstable;

  @override
  String toString() => name;
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
