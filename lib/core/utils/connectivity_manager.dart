// lib/core/utils/connectivity_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import './request_manager.dart';

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
  late final SharedPreferences _prefs;

  // Connection tracking
  Timer? _monitorTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  NetworkState _currentState = NetworkState.unknown;
  DateTime? _lastOnlineTime;
  DateTime? _lastSyncTime;
  bool _isInitialized = false;
  final bool _disposed = false;
  PrefsHelper? _prefsHelper;
  bool get isInitialized => _isInitialized;
  bool _isMonitoring = false;
  int _consecutiveFailures = 0;

  // Constants tuned for Pokedex app
  static const Duration _monitorInterval = Duration(seconds: 15);
  static const Duration _qualityTestTimeout = Duration(seconds: 5);
  static const Duration _backoffInterval = Duration(seconds: 30);
  static const Duration _minSyncInterval = Duration(minutes: 15);
  static const int _maxConsecutiveFailures = 3;
  static const String _testEndpoint = 'https://pokeapi.co/api/v2/pokemon/1';
  static const String _lastOnlineKey = 'last_online_timestamp';
  static const String _lastSyncKey = 'last_sync_timestamp';

  // Public stream access
  Stream<NetworkState> get networkStateStream => _networkStateController.stream;
  NetworkState get currentState => _currentState;
  bool get isOnline => _currentState.isOnline;
  bool get isHighSpeed => _currentState.isHighSpeed;
  bool get needsOptimization => _currentState.needsOptimization;

  /// Initialize with proper error handling and state persistence
  Future<void> initialize() async {
  if (_isInitialized || _disposed) return;

  try {
    _prefsHelper = await PrefsHelper.getInstance();
    final result = await _connectivity.checkConnectivity();
    _updateNetworkState(result);
    
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateNetworkState,
      onError: (e) => debugPrint('⚠️ Connectivity listener error: $e'),
    );

    _isInitialized = true;
    debugPrint('✅ ConnectivityManager initialized: ${_currentState.name}');
  } catch (e) {
    debugPrint('❌ ConnectivityManager initialization error: $e');
    rethrow;
  }
}
  /// Load persisted state from preferences
  Future<void> _loadPersistedState() async {
    final lastOnlineTimestamp = _prefs.getInt(_lastOnlineKey);
    if (lastOnlineTimestamp != null) {
      _lastOnlineTime =
          DateTime.fromMillisecondsSinceEpoch(lastOnlineTimestamp);
    }

    final lastSyncTimestamp = _prefs.getInt(_lastSyncKey);
    if (lastSyncTimestamp != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp);
    }
  }

  /// Enhanced connectivity check with quality testing and caching
  Future<bool> checkConnectivity() async {
    if (!_isInitialized) await initialize();

    try {
      final result = await _connectivity.checkConnectivity();
      if (result == ConnectivityResult.none) {
        _updateNetworkState(result);
        return false;
      }

      // Perform real connection test for reliability
      final isReachable = await _testConnection();
      _updateNetworkState(isReachable ? result : ConnectivityResult.none,
          forceNotify: true);

      return isReachable;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Connectivity check error: $e');
      }
      _updateNetworkState(ConnectivityResult.none);
      return false;
    }
  }

  /// Check if device is offline with caching
  Future<bool> isOffline() async {
    // Use cached state if recently checked
    if (_lastOnlineTime != null) {
      final timeSinceLastCheck = DateTime.now().difference(_lastOnlineTime!);
      if (timeSinceLastCheck < const Duration(seconds: 30)) {
        return !isOnline;
      }
    }
    return !(await checkConnectivity());
  }

  /// Start monitoring with smart backoff and battery optimization
  void _startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(_monitorInterval, (_) {
      if (_consecutiveFailures >= _maxConsecutiveFailures) {
        // Increase interval on repeated failures
        _monitorTimer?.cancel();
        _monitorTimer =
            Timer.periodic(_backoffInterval, (_) => _checkQuality());
      } else {
        _checkQuality();
      }
    });
  }

  /// Handle connectivity changes with debouncing and verification
  void _handleConnectivityChange(ConnectivityResult result) async {
    if (_currentState.type == result && !_currentState.needsOptimization)
      return;

    // Verify change with actual connection test
    final isReachable = await _testConnection();
    _updateNetworkState(isReachable ? result : ConnectivityResult.none,
        forceNotify: true);

    if (kDebugMode) {
      print('🌐 Network state changed: ${_currentState.name}');
    }
  }

  /// Test actual connection quality with timeout
  Future<bool> _testConnection() async {
    try {
      final response = await RequestManager().executeRequest(
        id: 'connectivity_test',
        request: () =>
            http.get(Uri.parse(_testEndpoint)).timeout(_qualityTestTimeout),
      );

      final success = response.statusCode == 200;
      if (success) {
        _consecutiveFailures = 0;
        _lastOnlineTime = DateTime.now();
        await _prefs.setInt(
            _lastOnlineKey, _lastOnlineTime!.millisecondsSinceEpoch);
      } else {
        _consecutiveFailures++;
      }

      return success;
    } catch (e) {
      _consecutiveFailures++;
      return false;
    }
  }

  /// Check network quality with response time tracking
  Future<void> _checkQuality() async {
    if (_currentState == NetworkState.offline) return;

    try {
      final startTime = DateTime.now();
      final isReachable = await _testConnection();

      if (isReachable) {
        final responseTime = DateTime.now().difference(startTime);
        _qualityTestResults[startTime] = responseTime;

        // Keep last 5 results for moving average
        if (_qualityTestResults.length > 5) {
          _qualityTestResults.remove(_qualityTestResults.keys.first);
        }

        _updateNetworkQuality();
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Quality check error: $e');
      }
    }
  }

  /// Update network quality based on response times and history
  void _updateNetworkQuality() {
    if (_qualityTestResults.isEmpty) return;

    // Calculate weighted moving average
    final weightedSum =
        _qualityTestResults.entries.fold<Duration>(Duration.zero, (sum, entry) {
      final age = DateTime.now().difference(entry.key);
      final weight = 1.0 / (age.inSeconds + 1);
      return sum + (entry.value * weight.toInt());
    });

    final avgResponseTime = weightedSum ~/ _qualityTestResults.length;

    NetworkState newState;
    if (avgResponseTime < const Duration(milliseconds: 300)) {
      newState = NetworkState.excellent;
    } else if (avgResponseTime < const Duration(milliseconds: 1000)) {
      newState = NetworkState.good;
    } else if (avgResponseTime < const Duration(milliseconds: 2000)) {
      newState = NetworkState.poor;
    } else {
      newState = NetworkState.unstable;
    }

    _updateNetworkState(_currentState.type, quality: newState);
  }

  /// Update network state with proper notifications and persistence
  void _updateNetworkState(
    ConnectivityResult result, {
    NetworkState? quality,
    bool forceNotify = false,
  }) {
    final newState = quality ?? _getNetworkState(result);
    if (_currentState == newState && !forceNotify) return;

    _currentState = newState;
    if (!_networkStateController.isClosed) {
      _networkStateController.add(newState);
    }

    // Update sync time for major state changes
    if (newState.isOnline && _lastSyncTime == null) {
      _lastSyncTime = DateTime.now();
      _prefs.setInt(_lastSyncKey, _lastSyncTime!.millisecondsSinceEpoch);
    }
  }

  /// Convert connectivity result to network state with quality consideration
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

  /// Get time since last successful connection
  Duration? getTimeSinceLastOnline() {
    if (_lastOnlineTime == null) return null;
    return DateTime.now().difference(_lastOnlineTime!);
  }

  /// Get time since last sync
  Duration? getTimeSinceLastSync() {
    if (_lastSyncTime == null) return null;
    return DateTime.now().difference(_lastSyncTime!);
  }

  /// Check if sync is needed based on interval
  bool needsSync() {
    final timeSinceSync = getTimeSinceLastSync();
    if (timeSinceSync == null) return true;
    return timeSinceSync > _minSyncInterval;
  }

  /// Check if was recently online within threshold
  bool wasRecentlyOnline({Duration threshold = const Duration(minutes: 5)}) {
    if (_lastOnlineTime == null) return false;
    return DateTime.now().difference(_lastOnlineTime!) < threshold;
  }

  /// Wait for connectivity with timeout and cancellation
  Future<bool> waitForConnectivity({Duration? timeout}) async {
    if (isOnline) return true;

    final completer = Completer<bool>();

    // Setup timeout
    Timer? timeoutTimer;
    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });
    }

    // Listen for connectivity
    StreamSubscription? subscription;
    subscription = networkStateStream.listen((state) {
      if (state.isOnline && !completer.isCompleted) {
        timeoutTimer?.cancel();
        completer.complete(true);
        subscription?.cancel();
      }
    });

    return completer.future;
  }

  /// Reset monitoring state and clear history
  void reset() {
    _consecutiveFailures = 0;
    _qualityTestResults.clear();
    _lastSyncTime = null;
    _prefs.remove(_lastSyncKey);
    _startMonitoring();
  }

  /// Stop monitoring
  void stopMonitoring() {
    _isMonitoring = false;
    _monitorTimer?.cancel();
  }

  /// Cleanup resources properly
  Future<void> dispose() async {
    stopMonitoring();
    await _connectivitySubscription?.cancel();
    await _networkStateController.close();
    _qualityTestResults.clear();
    _isInitialized = false;
  }
}

/// Enhanced network state enum with quality levels
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
