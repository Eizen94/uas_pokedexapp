// lib/core/utils/connectivity_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'request_manager.dart';

class ConnectivityManager {
  // Singleton instance
  static final ConnectivityManager _instance = ConnectivityManager._internal();
  factory ConnectivityManager() => _instance;
  ConnectivityManager._internal() {
    _initBehaviorSubjects();
  }

  // Connectivity instance
  final Connectivity _connectivity = Connectivity();
  final RequestManager _requestManager = RequestManager();
  SharedPreferences? _prefs;

  // Stream controllers
  final _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();
  final _onlineStatusController = StreamController<bool>.broadcast();

  // Subscription management
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _monitorTimer;

  // Current status tracking
  ConnectivityResult? _lastResult;
  bool _isInitialized = false;
  bool _isMonitoring = false;
  DateTime? _lastOnlineTime;

  // Constants
  static const String _lastOnlineKey = 'last_online_timestamp';
  static const Duration _monitorInterval = Duration(seconds: 30);

  // Public streams access
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;
  Stream<bool> get onlineStatus => _onlineStatusController.stream;

  // Initialize manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      _loadLastOnlineTime();

      // Get initial connectivity
      final initialResult = await _connectivity.checkConnectivity();
      _lastResult = initialResult;
      _updateConnectionStatus(initialResult);

      // Start monitoring
      await startMonitoring();

      _isInitialized = true;

      if (kDebugMode) {
        print('✅ ConnectivityManager initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ConnectivityManager initialization error: $e');
      }
      rethrow;
    }
  }

  // Start monitoring connectivity
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    try {
      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
        onError: (error) {
          if (kDebugMode) {
            print('❌ Connectivity monitoring error: $error');
          }
          _connectionStatusController.addError(error);
        },
      );

      // Start periodic monitoring
      _monitorTimer =
          Timer.periodic(_monitorInterval, (_) => _checkConnectivity());
      _isMonitoring = true;

      if (kDebugMode) {
        print('🔄 Started connectivity monitoring');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting connectivity monitoring: $e');
      }
      rethrow;
    }
  }

  // Stop monitoring
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
    _monitorTimer?.cancel();
    _isMonitoring = false;

    if (kDebugMode) {
      print('⏹️ Stopped connectivity monitoring');
    }
  }

  // Check current connectivity
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      return result != ConnectivityResult.none;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking connectivity: $e');
      }
      return false;
    }
  }

  // Update connection status
  void _updateConnectionStatus(ConnectivityResult result) async {
    if (result == _lastResult) return;

    final previousStatus = _getConnectionStatus(_lastResult);
    final currentStatus = _getConnectionStatus(result);
    final isOnline = result != ConnectivityResult.none;

    _lastResult = result;

    // Update status streams
    _connectionStatusController.add(currentStatus);
    _onlineStatusController.add(isOnline);

    if (kDebugMode) {
      print('🌐 Connection changed: $currentStatus (Online: $isOnline)');
    }

    // Handle online/offline transitions
    if (!previousStatus.isOnline && currentStatus.isOnline) {
      _handleOnlineTransition();
    } else if (previousStatus.isOnline && !currentStatus.isOnline) {
      _handleOfflineTransition();
    }
  }

  // Handle transition to online
  Future<void> _handleOnlineTransition() async {
    _lastOnlineTime = DateTime.now();
    await _saveLastOnlineTime();

    // Retry pending requests
    _requestManager.retryFailedRequests();

    if (kDebugMode) {
      print('🔵 Device is now online');
    }
  }

  // Handle transition to offline
  void _handleOfflineTransition() {
    if (kDebugMode) {
      print('🔴 Device is now offline');
    }
  }

  // Wait for connectivity with timeout
  Future<bool> waitForConnectivity({Duration? timeout}) async {
    if (await checkConnectivity()) return true;

    final completer = Completer<bool>();
    StreamSubscription? subscription;

    // Setup timeout
    Timer? timeoutTimer;
    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });
    }

    // Listen for connectivity
    subscription = onlineStatus.listen((isOnline) {
      if (isOnline && !completer.isCompleted) {
        timeoutTimer?.cancel();
        subscription?.cancel();
        completer.complete(true);
      }
    }, onError: (error) {
      timeoutTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    return completer.future;
  }

  // Load last online time from preferences
  void _loadLastOnlineTime() {
    final timestamp = _prefs?.getInt(_lastOnlineKey);
    if (timestamp != null) {
      _lastOnlineTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
  }

  // Save last online time to preferences
  Future<void> _saveLastOnlineTime() async {
    if (_lastOnlineTime != null) {
      await _prefs?.setInt(
        _lastOnlineKey,
        _lastOnlineTime!.millisecondsSinceEpoch,
      );
    }
  }

  // Check connectivity with active probe
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during connectivity check: $e');
      }
    }
  }

  // Initialize stream controllers
  void _initBehaviorSubjects() {
    // Add initial values
    _connectionStatusController.add(ConnectionStatus.unknown);
    _onlineStatusController.add(false);
  }

  // Convert ConnectivityResult to ConnectionStatus
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
      case ConnectivityResult.other:
        return ConnectionStatus.offline;
      default:
        return ConnectionStatus.unknown;
    }
  }

  // Get time since last online
  Duration? getTimeSinceLastOnline() {
    if (_lastOnlineTime == null) return null;
    return DateTime.now().difference(_lastOnlineTime!);
  }

  // Check if device was recently online
  bool wasRecentlyOnline({Duration threshold = const Duration(minutes: 5)}) {
    final timeSinceLastOnline = getTimeSinceLastOnline();
    if (timeSinceLastOnline == null) return false;
    return timeSinceLastOnline < threshold;
  }

  // Resource cleanup
  void dispose() {
    stopMonitoring();
    _connectionStatusController.close();
    _onlineStatusController.close();
    _isInitialized = false;

    if (kDebugMode) {
      print('🧹 ConnectivityManager disposed');
    }
  }
}

// Connection status enum
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

  @override
  String toString() => value;
}

// Extension methods for easy status checking
extension ConnectionStatusX on ConnectionStatus {
  bool get isOnline =>
      this != ConnectionStatus.offline && this != ConnectionStatus.unknown;

  bool get isWifi => this == ConnectionStatus.wifi;

  bool get isCellular => this == ConnectionStatus.cellular;

  bool get isEthernet => this == ConnectionStatus.ethernet;

  bool get isBluetooth => this == ConnectionStatus.bluetooth;

  bool get isVpn => this == ConnectionStatus.vpn;

  bool get isOffline => this == ConnectionStatus.offline;

  bool get isUnknown => this == ConnectionStatus.unknown;
}
