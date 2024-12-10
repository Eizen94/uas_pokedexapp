// lib/dev/tools/dev_tools.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import './test_screen.dart';
import '../../core/utils/api_helper.dart';
import '../../core/utils/connectivity_manager.dart';
import '../../core/utils/monitoring_manager.dart';
import '../../services/firebase_service.dart';

/// DevTools with comprehensive error handling, resource management
/// and proper initialization chain
class DevTools {
  // Singleton instance with lazy initialization
  static final DevTools _instance = DevTools._internal();
  factory DevTools() => _instance;
  DevTools._internal();

  // Core services
  final ApiHelper _apiHelper = ApiHelper();
  final ConnectivityManager _connectivityManager = ConnectivityManager();
  final MonitoringManager _monitoringManager = MonitoringManager();
  final FirebaseService _firebaseService = FirebaseService();
  final List<StreamSubscription> _activeSubscriptions = [];

  // Resource management
  final _resourceManager = _DevToolsResourceManager();

  // State management
  bool _isInitialized = false;
  bool _isDebugMode = false;
  bool _disposed = false;

  // Public getters
  bool get isInitialized => _isInitialized;
  bool get isDebugBuild => _isDebugMode;

  /// Initialize DevTools with proper error handling and state management
  Future<void> initialize() async {
    if (_disposed) {
      throw DevToolsException('Cannot initialize disposed instance');
    }

    if (_isInitialized) {
      if (kDebugMode) {
        print('DevTools already initialized');
      }
      return;
    }

    try {
      _isDebugMode = kDebugMode;

      if (_isDebugMode) {
        // Sequential initialization with error handling
        await Future.wait([
          _apiHelper.initialize().catchError(_handleInitError('ApiHelper')),
          _connectivityManager
              .initialize()
              .catchError(_handleInitError('ConnectivityManager')),
          _monitoringManager
              .startMonitoring()
              .catchError(_handleInitError('MonitoringManager')),
          _firebaseService
              .initialize()
              .catchError(_handleInitError('FirebaseService')),
        ]);

        // Setup state synchronization
        _setupStateSynchronization();

        if (kDebugMode) {
          print('✅ DevTools initialized successfully');
        }
      }

      _isInitialized = true;
    } catch (e) {
      await dispose();
      throw DevToolsException(
        'Initialization failed',
        originalError: e is Exception ? e : null,
      );
    }
  }

  /// Handle initialization errors
  Function _handleInitError(String service) {
    return (error) {
      if (kDebugMode) {
        print('❌ $service initialization error: $error');
      }
      throw DevToolsException(
        '$service initialization failed',
        originalError: error is Exception ? error : null,
      );
    };
  }

  /// Setup state synchronization between managers
  void _setupStateSynchronization() {
    if (_disposed) return;

    final subscription = _connectivityManager.networkStateStream.listen(
      (state) async {
        if (_disposed) return;

        try {
          // MonitoringManager & ApiHelper sudah handle state changes internally
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
    return const SizedBox.shrink();
  }

  /// Enhanced logging with error context
  void logDebug(String message) {
    if (_isDebugMode) {
      debugPrint('🔧 [DEBUG] $message');
    }
  }

  void logError(String message, [Object? error, StackTrace? stackTrace]) {
    if (_isDebugMode) {
      debugPrint('❌ [ERROR] $message');
      if (error != null) {
        debugPrint('Error details: $error');
        if (stackTrace != null) {
          debugPrint('Stack trace:\n$stackTrace');
        }
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
      'api': _apiHelper.isInitialized,
      'connectivity': _connectivityManager.isInitialized,
      'monitoring': _monitoringManager.isMonitoring,
      'firebase': _firebaseService.isInitialized,
    };
  }

  /// Resource cleanup with proper error handling
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;

    try {
      await Future.wait([
        _apiHelper.dispose(),
        _connectivityManager.dispose(),
        _monitoringManager.dispose(),
        _resourceManager.dispose(),
      ]);

      _isInitialized = false;

      if (kDebugMode) {
        print('🧹 DevTools disposed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during DevTools disposal: $e');
      }
    }
  }
}

/// Resource manager for DevTools
class _DevToolsResourceManager {
  final Map<String, Timer> _activeTimers = {};
  final List<StreamSubscription> _activeSubscriptions = [];

  void registerTimer(String id, Timer timer) {
    _activeTimers[id]?.cancel();
    _activeTimers[id] = timer;
  }

  void registerSubscription(StreamSubscription subscription) {
    _activeSubscriptions.add(subscription);
  }

  Future<void> dispose() async {
    for (var timer in _activeTimers.values) {
      timer.cancel();
    }

    await Future.wait(
      _activeSubscriptions.map((sub) => sub.cancel()),
    );

    _activeTimers.clear();
    _activeSubscriptions.clear();
  }
}

/// Custom exception for DevTools
class DevToolsException implements Exception {
  final String message;
  final String? code;
  final Exception? originalError;

  DevToolsException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() {
    return 'DevToolsException: $message${code != null ? ' ($code)' : ''}';
  }
}
