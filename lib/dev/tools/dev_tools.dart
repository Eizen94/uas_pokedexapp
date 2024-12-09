// lib/dev/tools/dev_tools.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import './test_screen.dart';
import '../../core/utils/api_helper.dart';
import '../../core/utils/connectivity_manager.dart';
import '../../core/utils/monitoring_manager.dart';
import '../../services/firebase_service.dart';

/// Development tools and utilities manager
class DevTools {
  // Singleton instance
  static final DevTools _instance = DevTools._internal();
  factory DevTools() => _instance;
  DevTools._internal();

  // Service instances
  final ApiHelper _apiHelper = ApiHelper();
  final ConnectivityManager _connectivityManager = ConnectivityManager();
  final MonitoringManager _monitoringManager = MonitoringManager();
  final FirebaseService _firebaseService = FirebaseService();

  // Resource management
  final Map<String, Timer> _cacheExpiryTimers = {};
  final List<StreamSubscription> _activeSubscriptions = [];

  bool _isInitialized = false;
  bool _isDebugMode = false;

  /// Initialize dev tools
  Future<void> initialize() async {
    try {
      _isDebugMode = kDebugMode;

      if (_isDebugMode) {
        await Future.wait([
          _apiHelper.initialize(),
          _connectivityManager.initialize(),
          _monitoringManager.startMonitoring(),
          _firebaseService.initialize(),
        ]);

        // Setup network state monitoring
        _setupNetworkMonitoring();

        if (kDebugMode) {
          debugPrint('✅ DevTools initialized');
        }
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DevTools initialization error: $e');
      }
      rethrow;
    }
  }

  void _setupNetworkMonitoring() {
    final subscription = _connectivityManager.networkStateStream.listen(
      (state) async {
        try {
          // MonitoringManager already listens to connectivity changes internally
          if (kDebugMode) {
            debugPrint('🔄 Network state changed: ${state.name}');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ Error handling network state: $e');
          }
        }
      },
    );

    _activeSubscriptions.add(subscription);
  }

  /// Check if running in development mode
  static bool get isDevMode => !const bool.fromEnvironment('dart.vm.product');

  /// Get test screen widget if in dev mode
  static Widget getTestScreen() {
    if (isDevMode) {
      return const TestScreen();
    }
    return const SizedBox.shrink(); // Empty widget for production
  }

  // Development mode checks
  bool get isDebugBuild => _isDebugMode;
  bool get isInitialized => _isInitialized;

  /// Debug helpers
  void logDebug(String message) {
    if (_isDebugMode) {
      debugPrint('🔧 [DEBUG] $message');
    }
  }

  void logError(String message, [Object? error]) {
    if (_isDebugMode) {
      debugPrint('❌ [ERROR] $message');
      if (error != null) {
        debugPrint('Stack trace:');
        debugPrint(error.toString());
      }
    }
  }

  void logWarning(String message) {
    if (_isDebugMode) {
      debugPrint('⚠️ [WARNING] $message');
    }
  }

  void logInfo(String message) {
    if (_isDebugMode) {
      debugPrint('ℹ️ [INFO] $message');
    }
  }

  /// Performance monitoring
  void logPerformance(String operation, Duration duration) {
    if (_isDebugMode) {
      debugPrint('⚡ [PERF] $operation took ${duration.inMilliseconds}ms');
    }
  }

  /// Network state helper
  Future<bool> checkConnectivity() async {
    if (!_isInitialized) return false;
    return _connectivityManager.checkConnectivity();
  }

  /// Cache helpers
  Future<void> clearAllCache() async {
    if (!_isInitialized) return;
    await _apiHelper.clearAllCache();
    logInfo('Cache cleared');
  }

  /// Service status
  Map<String, bool> getServiceStatus() {
    return {
      'api': _apiHelper.active,
      'connectivity': _connectivityManager.hasConnection,
      'monitoring': _monitoringManager.isMonitoring,
      'firebase': _firebaseService.active
    };
  }

  /// Resource cleanup
  Future<void> dispose() async {
    if (_isInitialized) {
      // Cancel timers
      for (var timer in _cacheExpiryTimers.values) {
        timer.cancel();
      }
      _cacheExpiryTimers.clear();

      // Cancel subscriptions
      for (var subscription in _activeSubscriptions) {
        await subscription.cancel();
      }
      _activeSubscriptions.clear();

      // Dispose services
      await Future.wait([
        _apiHelper.dispose(),
        _connectivityManager.dispose(),
        _monitoringManager.dispose(),
      ]);

      _isInitialized = false;

      if (kDebugMode) {
        debugPrint('🧹 DevTools disposed');
      }
    }
  }
}