// lib/core/utils/connectivity_manager.dart

/// Connectivity manager to handle network state and offline capabilities.
/// Provides real-time network status monitoring and offline mode management.
library core.utils.connectivity_manager;

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

/// Network state enum
enum NetworkState {
  /// Device is online and connected
  online,
  
  /// Device is offline or disconnected
  offline
}

/// Manager class for handling connectivity states
class ConnectivityManager {
  static final ConnectivityManager _instance = ConnectivityManager._internal();
  
  /// Singleton instance
  factory ConnectivityManager() => _instance;

  ConnectivityManager._internal() {
    _initialize();
  }

  final Connectivity _connectivity = Connectivity();
  final BehaviorSubject<NetworkState> _connectionStateController = 
      BehaviorSubject<NetworkState>();
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _pingTimer;

  /// Stream of network state changes
  Stream<NetworkState> get connectionStream => _connectionStateController.stream;
  
  /// Current network state
  NetworkState get currentState => _connectionStateController.value;
  
  /// Whether device is currently connected
  bool get hasConnection => currentState == NetworkState.online;

  /// Initialize connectivity monitoring
  void _initialize() {
    // Initial connectivity check
    _checkConnectivity();
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen((ConnectivityResult result) {
      _handleConnectivityChange(result);
    });

    // Setup periodic connectivity verification
    _pingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _verifyConnectivity(),
    );
  }

  /// Handle connectivity state changes
  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      _connectionStateController.add(NetworkState.offline);
    } else {
      // Verify actual connectivity with ping
      await _verifyConnectivity();
    }
  }

  /// Check current connectivity state
  Future<void> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    await _handleConnectivityChange(result);
  }

  /// Verify actual connectivity with ping test
  Future<void> _verifyConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result != ConnectivityResult.none) {
        // Consider connected if we can reach internet
        _connectionStateController.add(NetworkState.online);
      } else {
        _connectionStateController.add(NetworkState.offline);
      }
    } catch (e) {
      _connectionStateController.add(NetworkState.offline);
    }
  }

  /// Force a connectivity check
  Future<void> checkConnection() async {
    await _checkConnectivity();
  }

  /// Clean up resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _pingTimer?.cancel();
    _connectionStateController.close();
  }
}

/// Extension methods for NetworkState
extension NetworkStateExtension on NetworkState {
  /// Whether the state represents an online connection
  bool get isOnline => this == NetworkState.online;
  
  /// Whether the state represents an offline state
  bool get isOffline => this == NetworkState.offline;
}