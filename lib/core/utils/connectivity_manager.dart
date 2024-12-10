// lib/core/utils/connectivity_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import './request_manager.dart';
import '../utils/prefs_helper.dart';
import '../constants/api_paths.dart';

/// Enhanced connectivity manager optimized for Pokedex app with improved
/// offline support and network quality monitoring
class ConnectivityManager {
  // Singleton with proper initialization
  static final ConnectivityManager _instance = ConnectivityManager._internal();
  factory ConnectivityManager() => _instance;
  ConnectivityManager._internal();

  // Core components
  final Connectivity _connectivity = Connectivity();
  final _networkStateController = StreamController<NetworkState>.broadcast();
  final _qualityTestResults = <DateTime, Duration>{};
  final _lock = Lock();

  // State tracking
  Timer? _monitorTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  NetworkState _currentState = NetworkState.unknown;
  DateTime? _lastOnlineTime;
  DateTime? _lastSyncTime;
  bool _isInitialized = false;
  bool _isDisposed = false;
  PrefsHelper? _prefsHelper;
  bool _isMonitoring = false;
  int _consecutiveFailures = 0;

  // Constants tuned for performance
  static const Duration _monitorInterval = Duration(seconds: 15);
  static const Duration _qualityTestTimeout = Duration(seconds: 5);
  static const Duration _backoffInterval = Duration(seconds: 30);
  static const Duration _minSyncInterval = Duration(minutes: 15);
  static const int _maxConsecutiveFailures = 3;
  static const String _lastOnlineKey = 'last_online_timestamp';
  static const String _lastSyncKey = 'last_sync_timestamp';

  // Public access
  Stream<NetworkState> get networkStateStream => _networkStateController.stream;
  NetworkState get currentState => _currentState;
  bool get isOnline => _currentState.isOnline;
  bool get isHighSpeed => _currentState.isHighSpeed;
  bool get needsOptimization => _currentState.needsOptimization;
  bool get isInitialized => _isInitialized;

  /// Initialize with proper error handling and state persistence
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      await _lock.synchronized(() async {
        _prefsHelper = await PrefsHelper.getInstance();
        await _loadPersistedState();

        final result = await _connectivity.checkConnectivity();
        _updateNetworkState(result);

        // Setup connectivity listener
        _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
          _handleConnectivityChange,
          onError: (e) => debugPrint('⚠️ Connectivity listener error: $e'),
        );

        _isInitialized = true;
      });

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

  /// Load persisted state from preferences
  Future<void> _loadPersistedState() async {
    try {
      final prefs = _prefsHelper?.prefs;
      if (prefs == null) return;

      final lastOnlineTimestamp = prefs.getInt(_lastOnlineKey);
      if (lastOnlineTimestamp != null) {
        _lastOnlineTime =
            DateTime.fromMillisecondsSinceEpoch(lastOnlineTimestamp);
      }

      final lastSyncTimestamp = prefs.getInt(_lastSyncKey);
      if (lastSyncTimestamp != null) {
        _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error loading persisted state: $e');
      }
    }
  }

  /// Check connectivity with quality testing
  Future<bool> checkConnectivity() async {
    if (!_isInitialized) await initialize();

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

  /// Test actual connection with timeout
  Future<bool> _testConnection() async {
    try {
      final response = await RequestManager().executeRequest(
        id: 'connectivity_test',
        request: () => http
            .get(Uri.parse(ApiPaths.pokeApiBase))
            .timeout(_qualityTestTimeout),
      );

      final success = response.statusCode == 200;
      if (success) {
        _consecutiveFailures = 0;
        _lastOnlineTime = DateTime.now();
        await _prefsHelper?.prefs
            ?.setInt(_lastOnlineKey, _lastOnlineTime!.millisecondsSinceEpoch);
      } else {
        _consecutiveFailures++;
      }

      return success;
    } catch (e) {
      _consecutiveFailures++;
      return false;
    }
  }

  /// Handle connectivity changes with verification
  void _handleConnectivityChange(ConnectivityResult result) async {
    if (!_isInitialized || _isDisposed) return;

    if (_currentState.type == result && !_currentState.needsOptimization) {
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

  /// Update network state with proper notifications
  void _updateNetworkState(
    ConnectivityResult result, {
    NetworkState? quality,
    bool forceNotify = false,
  }) {
    final newState = quality ?? _getNetworkState(result);
    if (_currentState == newState && !forceNotify) return;

    _currentState = newState;
    if (!_networkStateController.isClosed && !_isDisposed) {
      _networkStateController.add(newState);
    }

    // Update sync time for major state changes
    if (newState.isOnline && _lastSyncTime == null) {
      _lastSyncTime = DateTime.now();
      _prefsHelper?.prefs
          ?.setInt(_lastSyncKey, _lastSyncTime!.millisecondsSinceEpoch);
    }
  }

  /// Convert connectivity result to network state
  NetworkState _getNetworkState(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.mobile:
        return NetworkState.mobile;
      case ConnectivityResult.wifi:
        return NetworkState.wifi;
      case ConnectivityResult.ethernet:
        return NetworkState.ethernet;
      case ConnectivityResult.none:
        return NetworkState.offline;
      default:
        return NetworkState.unknown;
    }
  }

  /// Resource cleanup
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _monitorTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _networkStateController.close();
    _isInitialized = false;
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

  /// Get connectivity type
  ConnectivityResult get type {
    switch (this) {
      case NetworkState.wifi:
        return ConnectivityResult.wifi;
      case NetworkState.mobile:
        return ConnectivityResult.mobile;
      case NetworkState.ethernet:
        return ConnectivityResult.ethernet;
      default:
        return ConnectivityResult.none;
    }
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
