// lib/dev/tools/dev_tools.dart

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

  bool _isInitialized = false;
  bool _isDebugMode = false;

  /// Initialize dev tools
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isDebugMode = kDebugMode;

      if (_isDebugMode) {
        await Future.wait([
          _apiHelper.initialize(),
          _connectivityManager.initialize(),
          _monitoringManager.initialize(),
          _firebaseService.initialize(),
        ]);

        if (kDebugMode) {
          print('✅ DevTools initialized');
        }
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ DevTools initialization failed: $e');
      }
      rethrow;
    }
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

  /// Development mode checks
  bool get isDebugBuild => _isDebugMode;
  bool get isInitialized => _isInitialized;

  /// Debug helpers
  void logDebug(String message) {
    if (_isDebugMode) {
      print('🔧 [DEBUG] $message');
    }
  }

  void logError(String message, [Object? error]) {
    if (_isDebugMode) {
      print('❌ [ERROR] $message');
      if (error != null) {
        print('Stack trace:');
        print(error);
      }
    }
  }

  void logWarning(String message) {
    if (_isDebugMode) {
      print('⚠️ [WARNING] $message');
    }
  }

  void logInfo(String message) {
    if (_isDebugMode) {
      print('ℹ️ [INFO] $message');
    }
  }

  /// Performance monitoring
  void logPerformance(String operation, Duration duration) {
    if (_isDebugMode) {
      print('⚡ [PERF] $operation took ${duration.inMilliseconds}ms');
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
      'api': _apiHelper.isInitialized,
      'connectivity': _connectivityManager.isInitialized,
      'monitoring': _monitoringManager.isMonitoring,
      'firebase': _firebaseService.isInitialized,
    };
  }

  /// Resource cleanup
  Future<void> dispose() async {
    if (_isInitialized) {
      await Future.wait([
        _apiHelper.dispose(),
        _connectivityManager.dispose(),
        _monitoringManager.dispose(),
      ]);
      _isInitialized = false;
    }
  }
}
