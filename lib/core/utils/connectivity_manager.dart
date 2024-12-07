// lib/core/utils/connectivity_manager.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

class ConnectivityManager {
  // Singleton instance
  static final ConnectivityManager _instance = ConnectivityManager._internal();
  factory ConnectivityManager() => _instance;
  ConnectivityManager._internal();

  // Dependencies
  final Connectivity _connectivity = Connectivity();

  // Stream controllers
  final _connectivityController = BehaviorSubject<ConnectivityStatus>();
  final _isOnlineController = BehaviorSubject<bool>.seeded(true);

  // Subscription management
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isInitialized = false;

  // Public access to streams
  Stream<ConnectivityStatus> get status => _connectivityController.stream;
  Stream<bool> get isOnline => _isOnlineController.stream;

  // Current status
  ConnectivityStatus get currentStatus => _connectivityController.value;
  bool get isCurrentlyOnline => _isOnlineController.value;

  // Initialize the manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get initial connectivity status
      final initialResult = await _connectivity.checkConnectivity();
      _updateStatus(initialResult);

      // Listen for subsequent connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateStatus,
        onError: (error) {
          if (kDebugMode) {
            print('❌ Connectivity monitoring error: $error');
          }
          _connectivityController.addError(error);
        },
      );

      _isInitialized = true;

      if (kDebugMode) {
        print('✅ Connectivity manager initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize connectivity manager: $e');
      }
      _connectivityController.addError(e);
    }
  }

  // Update connectivity status
  void _updateStatus(ConnectivityResult result) {
    final status = _mapResultToStatus(result);
    final isOnline = status != ConnectivityStatus.offline;

    if (kDebugMode) {
      print('🌐 Connectivity changed: $status (Online: $isOnline)');
    }

    _connectivityController.add(status);
    _isOnlineController.add(isOnline);
  }

  // Map ConnectivityResult to our custom status
  ConnectivityStatus _mapResultToStatus(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return ConnectivityStatus.wifi;
      case ConnectivityResult.mobile:
        return ConnectivityStatus.cellular;
      case ConnectivityResult.ethernet:
        return ConnectivityStatus.ethernet;
      case ConnectivityResult.bluetooth:
        return ConnectivityStatus.bluetooth;
      case ConnectivityResult.vpn:
        return ConnectivityStatus.vpn;
      case ConnectivityResult.none:
      case ConnectivityResult.other:
        return ConnectivityStatus.offline;
    }
  }

  // Check current connectivity
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking connectivity: $e');
      }
      return false;
    }
  }

  // Wait for connectivity
  Future<void> waitForConnectivity({Duration? timeout}) async {
    if (await checkConnectivity()) return;

    final completer = Completer<void>();
    StreamSubscription? subscription;

    // Setup timeout if specified
    Timer? timeoutTimer;
    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException('Waited too long for connectivity'),
          );
        }
      });
    }

    // Listen for connectivity
    subscription = isOnline.listen((online) {
      if (online && !completer.isCompleted) {
        timeoutTimer?.cancel();
        subscription?.cancel();
        completer.complete();
      }
    }, onError: (error) {
      timeoutTimer?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    return completer.future;
  }

  // Resource cleanup
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
    _isOnlineController.close();
    _isInitialized = false;
  }
}

// Connectivity status enum
enum ConnectivityStatus {
  wifi('WiFi'),
  cellular('Cellular'),
  ethernet('Ethernet'),
  bluetooth('Bluetooth'),
  vpn('VPN'),
  offline('Offline');

  final String value;
  const ConnectivityStatus(this.value);

  @override
  String toString() => value;
}

// Extension methods for easy status checking
extension ConnectivityStatusX on ConnectivityStatus {
  bool get isOnline => this != ConnectivityStatus.offline;

  bool get isWifi => this == ConnectivityStatus.wifi;

  bool get isCellular => this == ConnectivityStatus.cellular;

  bool get isEthernet => this == ConnectivityStatus.ethernet;

  bool get isBluetooth => this == ConnectivityStatus.bluetooth;

  bool get isVpn => this == ConnectivityStatus.vpn;

  bool get isOffline => this == ConnectivityStatus.offline;
}
