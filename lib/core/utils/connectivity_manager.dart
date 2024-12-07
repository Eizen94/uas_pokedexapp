// lib/core/utils/connectivity_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'request_manager.dart';

/// Manages network connectivity with offline support and background sync
class ConnectivityManager {
  // Singleton instance
  static final ConnectivityManager _instance = ConnectivityManager._internal();
  factory ConnectivityManager() => _instance;
  ConnectivityManager._internal() {
    _initializeStreams();
  }

  // Core components
  final _connectivity = Connectivity();
  final _requestManager = RequestManager();
  SharedPreferences? _prefs;

  // Stream controllers for status updates
  final _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();
  final _networkQualityController =
      StreamController<NetworkQuality>.broadcast();
  final _onlineStatusController = StreamController<bool>.broadcast();
  final _syncStatusController = StreamController<SyncStatus>.broadcast();

  // Connection management
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _monitorTimer;
  Timer? _speedTestTimer;

  // Status tracking
  ConnectivityResult? _lastResult;
  bool _isInitialized = false;
  bool _isMonitoring = false;
  bool _isSyncing = false;
  DateTime? _lastOnlineTime;
  DateTime? _lastSyncTime;
  int _failedTests = 0;

  // Queues for offline operations
  final _offlineOperations = <OfflineOperation>[];
  final _syncInProgress = <String>{};

  // Constants
  static const String _lastOnlineKey = 'last_online_timestamp';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const Duration _monitorInterval = Duration(seconds: 30);
  static const Duration _speedTestInterval = Duration(minutes: 5);
  static const Duration _syncTimeout = Duration(minutes: 2);
  static const int _maxFailedTests = 3;
  static const int _maxRetries = 3;

  // Stream getters
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;
  Stream<NetworkQuality> get networkQuality => _networkQualityController.stream;
  Stream<bool> get onlineStatus => _onlineStatusController.stream;
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  /// Initialize the connectivity manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize preferences
      _prefs = await SharedPreferences.getInstance();
      await _loadLastTimestamps();

      // Get initial connectivity
      final initialResult = await _connectivity.checkConnectivity();
      _lastResult = initialResult;
      await _updateConnectionStatus(initialResult);

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

  /// Start monitoring connectivity
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

      // Start network quality monitoring
      _speedTestTimer =
          Timer.periodic(_speedTestInterval, (_) => _checkNetworkQuality());

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

  /// Stop monitoring
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
    _monitorTimer?.cancel();
    _speedTestTimer?.cancel();
    _isMonitoring = false;

    if (kDebugMode) {
      print('⏹️ Stopped connectivity monitoring');
    }
  }

  /// Check current connectivity
  Future<ConnectionStatus> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final status = _getConnectionStatus(result);
      await _updateConnectionStatus(result);
      return status;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking connectivity: $e');
      }
      return ConnectionStatus.unknown;
    }
  }

  /// Update connection status and handle transitions
  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    if (result == _lastResult) return;

    final previousStatus = _getConnectionStatus(_lastResult);
    final currentStatus = _getConnectionStatus(result);
    final isOnline = currentStatus.isOnline;

    _lastResult = result;

    // Update status streams
    _connectionStatusController.add(currentStatus);
    _onlineStatusController.add(isOnline);

    if (kDebugMode) {
      print('🌐 Connection changed: $currentStatus (Online: $isOnline)');
    }

    // Handle online/offline transitions
    if (!previousStatus.isOnline && currentStatus.isOnline) {
      await _handleOnlineTransition();
    } else if (previousStatus.isOnline && !currentStatus.isOnline) {
      await _handleOfflineTransition();
    }
  }

  /// Handle transition to online state
  Future<void> _handleOnlineTransition() async {
    _lastOnlineTime = DateTime.now();
    await _saveLastOnlineTime();

    // Check for pending offline operations
    if (_offlineOperations.isNotEmpty) {
      await _processPendingOperations();
    }

    if (kDebugMode) {
      print('🔵 Device is now online');
    }
  }

  /// Handle transition to offline state
  Future<void> _handleOfflineTransition() async {
    // Cancel non-critical ongoing requests
    _requestManager.cancelAllRequests();

    if (kDebugMode) {
      print('🔴 Device is now offline');
    }
  }

  /// Check network quality
  Future<void> _checkNetworkQuality() async {
    try {
      final startTime = DateTime.now();
      final result = await _connectivity.checkConnectivity();
      final endTime = DateTime.now();

      // Simple response time based quality check
      final responseTime = endTime.difference(startTime);
      final quality = _calculateNetworkQuality(responseTime);

      _networkQualityController.add(quality);

      // Update failed tests counter
      if (quality == NetworkQuality.poor) {
        _failedTests++;
        if (_failedTests >= _maxFailedTests) {
          await _updateConnectionStatus(ConnectivityResult.none);
        }
      } else {
        _failedTests = 0;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error checking network quality: $e');
      }
    }
  }

  /// Calculate network quality based on response time
  NetworkQuality _calculateNetworkQuality(Duration responseTime) {
    if (responseTime.inMilliseconds < 300) {
      return NetworkQuality.excellent;
    } else if (responseTime.inMilliseconds < 1000) {
      return NetworkQuality.good;
    } else if (responseTime.inMilliseconds < 3000) {
      return NetworkQuality.fair;
    } else {
      return NetworkQuality.poor;
    }
  }

  /// Queue operation for offline processing
  Future<void> queueOfflineOperation(OfflineOperation operation) async {
    _offlineOperations.add(operation);
    await _saveOfflineOperations();

    if (kDebugMode) {
      print('📝 Queued offline operation: ${operation.id}');
    }
  }

  /// Process pending offline operations
  Future<void> _processPendingOperations() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      _syncStatusController.add(SyncStatus.inProgress);

      for (final operation in _offlineOperations) {
        if (_syncInProgress.contains(operation.id)) continue;

        try {
          _syncInProgress.add(operation.id);
          await operation.execute();
          _offlineOperations.remove(operation);
          _syncInProgress.remove(operation.id);
        } catch (e) {
          if (kDebugMode) {
            print(
                '⚠️ Error processing offline operation: ${operation.id} - $e');
          }
          operation.retryCount++;
          if (operation.retryCount >= _maxRetries) {
            _offlineOperations.remove(operation);
          }
          _syncInProgress.remove(operation.id);
        }
      }

      await _saveOfflineOperations();
      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();
      _syncStatusController.add(SyncStatus.completed);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error processing offline operations: $e');
      }
      _syncStatusController.add(SyncStatus.failed);
    } finally {
      _isSyncing = false;
    }
  }

  /// Load timestamps from preferences
  Future<void> _loadLastTimestamps() async {
    final onlineTimestamp = _prefs?.getInt(_lastOnlineKey);
    final syncTimestamp = _prefs?.getInt(_lastSyncKey);

    if (onlineTimestamp != null) {
      _lastOnlineTime = DateTime.fromMillisecondsSinceEpoch(onlineTimestamp);
    }
    if (syncTimestamp != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(syncTimestamp);
    }
  }

  /// Save last online time
  Future<void> _saveLastOnlineTime() async {
    if (_lastOnlineTime != null) {
      await _prefs?.setInt(
          _lastOnlineKey, _lastOnlineTime!.millisecondsSinceEpoch);
    }
  }

  /// Save last sync time
  Future<void> _saveLastSyncTime() async {
    if (_lastSyncTime != null) {
      await _prefs?.setInt(_lastSyncKey, _lastSyncTime!.millisecondsSinceEpoch);
    }
  }

  /// Save offline operations
  Future<void> _saveOfflineOperations() async {
    // Implement persistent storage for offline operations if needed
  }

  /// Initialize stream controllers
  void _initializeStreams() {
    _connectionStatusController.add(ConnectionStatus.unknown);
    _networkQualityController.add(NetworkQuality.unknown);
    _onlineStatusController.add(false);
    _syncStatusController.add(SyncStatus.idle);
  }

  /// Get connection status from result
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

  /// Get time since last online
  Duration? getTimeSinceLastOnline() {
    if (_lastOnlineTime == null) return null;
    return DateTime.now().difference(_lastOnlineTime!);
  }

  /// Get time since last sync
  Duration? getTimeSinceLastSync() {
    if (_lastSyncTime == null) return null;
    return DateTime.now().difference(_lastSyncTime!);
  }

  /// Check if device was recently online
  bool wasRecentlyOnline({Duration threshold = const Duration(minutes: 5)}) {
    final timeSinceLastOnline = getTimeSinceLastOnline();
    if (timeSinceLastOnline == null) return false;
    return timeSinceLastOnline < threshold;
  }

  /// Wait for connectivity with timeout
  Future<bool> waitForConnectivity({Duration? timeout}) async {
    if (await checkConnectivity() != ConnectionStatus.offline) {
      return true;
    }

    final completer = Completer<bool>();
    StreamSubscription? subscription;

    void complete(bool result) {
      subscription?.cancel();
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    // Setup timeout
    Timer? timeoutTimer;
    if (timeout != null) {
      timeoutTimer = Timer(timeout, () => complete(false));
    }

    // Listen for connectivity
    subscription = onlineStatus.listen(
      (isOnline) {
        if (isOnline) {
          timeoutTimer?.cancel();
          complete(true);
        }
      },
      onError: (error) {
        timeoutTimer?.cancel();
        complete(false);
      },
    );

    return completer.future;
  }

  /// Resource cleanup
  void dispose() {
    stopMonitoring();
    _connectionStatusController.close();
    _networkQualityController.close();
    _onlineStatusController.close();
    _syncStatusController.close();
    _isInitialized = false;

    if (kDebugMode) {
      print('🧹 ConnectivityManager disposed');
    }
  }
}

/// Connection status enum
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

/// Network quality enum
enum NetworkQuality {
  excellent('Excellent'),
  good('Good'),
  fair('Fair'),
  poor('Poor'),
  unknown('Unknown');

  final String value;
  const NetworkQuality(this.value);

  @override
  String toString() => value;
}

/// Sync status enum
enum SyncStatus {
  idle('Idle'),
  inProgress('In Progress'),
  completed('Completed'),
  failed('Failed');

  final String value;
  const SyncStatus(this.value);

  @override
  String toString() => value;
}

/// Offline operation class
class OfflineOperation {
  final String id;
  final Future<void> Function() execute;
  int retryCount = 0;

  OfflineOperation({
    required this.id,
    required this.execute,
  });
}

/// Extension methods for connection status
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

  bool get isHighSpeed =>
      this == ConnectionStatus.wifi || this == ConnectionStatus.ethernet;

  bool get isLowSpeed =>
      this == ConnectionStatus.cellular || this == ConnectionStatus.bluetooth;

  bool get isMobile => this == ConnectionStatus.cellular;

  bool get isStable =>
      this == ConnectionStatus.wifi ||
      this == ConnectionStatus.ethernet ||
      this == ConnectionStatus.vpn;

  NetworkQuality get expectedQuality {
    switch (this) {
      case ConnectionStatus.wifi:
      case ConnectionStatus.ethernet:
        return NetworkQuality.excellent;
      case ConnectionStatus.cellular:
      case ConnectionStatus.vpn:
        return NetworkQuality.good;
      case ConnectionStatus.bluetooth:
        return NetworkQuality.fair;
      case ConnectionStatus.offline:
        return NetworkQuality.poor;
      default:
        return NetworkQuality.unknown;
    }
  }

  bool canHandle(RequestPriority priority) {
    switch (priority) {
      case RequestPriority.high:
        return isOnline;
      case RequestPriority.normal:
        return isHighSpeed || isVpn;
      case RequestPriority.low:
        return isHighSpeed;
    }
  }
}

/// Extension methods for network quality
extension NetworkQualityX on NetworkQuality {
  bool get isGoodEnough =>
      this == NetworkQuality.excellent || this == NetworkQuality.good;

  bool get needsImprovement =>
      this == NetworkQuality.fair || this == NetworkQuality.poor;

  bool get isUnusable => this == NetworkQuality.poor;

  bool get isUnknown => this == NetworkQuality.unknown;

  int get minimumRetryDelay {
    switch (this) {
      case NetworkQuality.excellent:
        return 100; // 100ms
      case NetworkQuality.good:
        return 250; // 250ms
      case NetworkQuality.fair:
        return 500; // 500ms
      case NetworkQuality.poor:
        return 1000; // 1s
      default:
        return 2000; // 2s
    }
  }

  bool canHandle(RequestPriority priority) {
    switch (priority) {
      case RequestPriority.high:
        return this != NetworkQuality.poor;
      case RequestPriority.normal:
        return isGoodEnough;
      case RequestPriority.low:
        return this == NetworkQuality.excellent;
    }
  }
}

/// Extension methods for sync status
extension SyncStatusX on SyncStatus {
  bool get isActive => this == SyncStatus.inProgress;

  bool get isComplete => this == SyncStatus.completed;

  bool get hasFailed => this == SyncStatus.failed;

  bool get needsRetry => this == SyncStatus.failed;

  bool get canStart => this == SyncStatus.idle || this == SyncStatus.failed;
}
