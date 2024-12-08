// lib/core/utils/connectivity_manager.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'request_manager.dart';

/// Manages network connectivity with improved offline support and background sync.
/// Includes proper cleanup, thread safety, and efficient queue management.
class ConnectivityManager {
  // Singleton pattern with proper initialization
  static final ConnectivityManager _instance = ConnectivityManager._internal();
  factory ConnectivityManager() => _instance;
  ConnectivityManager._internal() {
    _initializeStreams();
  }

  // Core components with proper type safety
  final Connectivity _connectivity = Connectivity();
  final RequestManager _requestManager = RequestManager();
  late SharedPreferences _prefs;

  // Stream controllers with proper cleanup
  final StreamController<ConnectionStatus> _connectionStatusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<NetworkQuality> _networkQualityController =
      StreamController<NetworkQuality>.broadcast();
  final StreamController<bool> _onlineStatusController =
      StreamController<bool>.broadcast();
  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();

  // Connection management with safety checks
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _monitorTimer;
  Timer? _speedTestTimer;

  // Status tracking with thread safety
  ConnectivityResult? _lastResult;
  bool _isInitialized = false;
  bool _isMonitoring = false;
  bool _isSyncing = false;
  DateTime? _lastOnlineTime;
  DateTime? _lastSyncTime;
  int _failedTests = 0;

  // Queue system with bounded size
  final _boundedQueue = BoundedOperationQueue(maxSize: 1000);
  final _syncInProgress = <String>{};

  // Constants
  static const String _lastOnlineKey = 'last_online_timestamp';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const Duration _monitorInterval = Duration(seconds: 30);
  static const Duration _speedTestInterval = Duration(minutes: 5);
  static const Duration _syncTimeout = Duration(minutes: 2);
  static const int _maxFailedTests = 3;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Stream getters
  Stream<ConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;
  Stream<NetworkQuality> get networkQuality => _networkQualityController.stream;
  Stream<bool> get onlineStatus => _onlineStatusController.stream;
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  // Initialize streams safely
  void _initializeStreams() {
    _connectionStatusController.add(ConnectionStatus.unknown);
    _networkQualityController.add(NetworkQuality.unknown);
    _onlineStatusController.add(false);
    _syncStatusController.add(SyncStatus.idle);
  }

  /// Initialize the connectivity manager with proper error handling
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize preferences safely
      _prefs = await SharedPreferences.getInstance();
      await _loadLastTimestamps();

      // Get initial connectivity with timeout
      final initialResult = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(seconds: 5));
      _lastResult = initialResult;
      await _updateConnectionStatus(initialResult);

      // Start monitoring with safety checks
      await startMonitoring();
      _isInitialized = true;

      if (kDebugMode) {
        print('✅ ConnectivityManager initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ConnectivityManager initialization error: $e');
      }
      _isInitialized = false;
      rethrow;
    }
  }

  /// Start monitoring connectivity with proper cleanup
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    try {
      // Set up connectivity listener with error handling
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
        onError: (error) {
          if (kDebugMode) {
            print('❌ Connectivity monitoring error: $error');
          }
          _connectionStatusController.addError(error);
        },
        cancelOnError: false,
      );

      // Start periodic monitoring with safety checks
      _monitorTimer?.cancel();
      _monitorTimer = Timer.periodic(
        _monitorInterval,
        (_) => _checkConnectivity(),
      );

      // Start network quality monitoring
      _speedTestTimer?.cancel();
      _speedTestTimer = Timer.periodic(
        _speedTestInterval,
        (_) => _checkNetworkQuality(),
      );

      _isMonitoring = true;

      if (kDebugMode) {
        print('🔄 Started connectivity monitoring');
      }
    } catch (e) {
      _isMonitoring = false;
      if (kDebugMode) {
        print('❌ Error starting connectivity monitoring: $e');
      }
      rethrow;
    }
  }

  /// Stop monitoring with proper cleanup
  Future<void> stopMonitoring() async {
    await _connectivitySubscription?.cancel();
    _monitorTimer?.cancel();
    _speedTestTimer?.cancel();
    _isMonitoring = false;

    if (kDebugMode) {
      print('⏹️ Stopped connectivity monitoring');
    }
  }

  /// Check current connectivity with timeout
  Future<ConnectionStatus> checkConnectivity() async {
    try {
      final result = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(seconds: 5));
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

  /// Update connection status with proper state management
  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    if (result == _lastResult) return;

    final previousStatus = _getConnectionStatus(_lastResult);
    final currentStatus = _getConnectionStatus(result);
    final isOnline = currentStatus.isOnline;

    _lastResult = result;

    // Update status streams safely
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(currentStatus);
    }
    if (!_onlineStatusController.isClosed) {
      _onlineStatusController.add(isOnline);
    }

    if (kDebugMode) {
      print('🌐 Connection changed: $currentStatus (Online: $isOnline)');
    }

    // Handle transitions with proper error handling
    if (!previousStatus.isOnline && currentStatus.isOnline) {
      await _handleOnlineTransition();
    } else if (previousStatus.isOnline && !currentStatus.isOnline) {
      await _handleOfflineTransition();
    }
  }

  /// Handle transition to online state with retry mechanism
  Future<void> _handleOnlineTransition() async {
    _lastOnlineTime = DateTime.now();
    await _saveLastOnlineTime();

    // Process pending operations with retry
    if (_boundedQueue.isNotEmpty) {
      await _processPendingOperationsWithRetry();
    }

    if (kDebugMode) {
      print('🔵 Device is now online');
    }
  }

  /// Handle transition to offline state with proper cleanup
  Future<void> _handleOfflineTransition() async {
    // Cancel non-critical requests
    await _requestManager.cancelNonCriticalRequests();

    if (kDebugMode) {
      print('🔴 Device is now offline');
    }
  }

  /// Process pending operations with retry mechanism
  Future<void> _processPendingOperationsWithRetry() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      _syncStatusController.add(SyncStatus.inProgress);

      while (_boundedQueue.isNotEmpty) {
        final operation = await _boundedQueue.dequeue();
        if (_syncInProgress.contains(operation.id)) continue;

        try {
          _syncInProgress.add(operation.id);
          await _executeWithRetry(
            operation: () => operation.execute(),
            maxRetries: _maxRetries,
            retryDelay: _retryDelay,
          );
          _syncInProgress.remove(operation.id);
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Error processing operation: ${operation.id} - $e');
          }
          _syncInProgress.remove(operation.id);

          // Add back to queue if should retry
          if (operation.retryCount < _maxRetries) {
            operation.retryCount++;
            await _boundedQueue.enqueue(operation);
          }
        }
      }

      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();
      _syncStatusController.add(SyncStatus.completed);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error processing pending operations: $e');
      }
      _syncStatusController.add(SyncStatus.failed);
    } finally {
      _isSyncing = false;
    }
  }

  /// Execute operation with retry mechanism
  Future<T> _executeWithRetry<T>({
    required Future<T> Function() operation,
    required int maxRetries,
    required Duration retryDelay,
  }) async {
    int attempts = 0;

    while (true) {
      try {
        attempts++;
        return await operation();
      } catch (e) {
        if (attempts >= maxRetries) rethrow;
        await Future.delayed(retryDelay * attempts);
      }
    }
  }

  /// Check network quality with timeout
  Future<void> _checkNetworkQuality() async {
    try {
      final startTime = DateTime.now();
      final result = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(seconds: 5));
      final endTime = DateTime.now();

      final responseTime = endTime.difference(startTime);
      final quality = _calculateNetworkQuality(responseTime);

      if (!_networkQualityController.isClosed) {
        _networkQualityController.add(quality);
      }

      // Update failed tests counter with safety checks
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

  /// Queue operation for offline processing with bounds checking
  Future<void> queueOfflineOperation(OfflineOperation operation) async {
    await _boundedQueue.enqueue(operation);

    if (kDebugMode) {
      print('📝 Queued offline operation: ${operation.id}');
    }
  }

  /// Load timestamps from preferences safely
  Future<void> _loadLastTimestamps() async {
    final onlineTimestamp = _prefs.getInt(_lastOnlineKey);
    final syncTimestamp = _prefs.getInt(_lastSyncKey);

    if (onlineTimestamp != null) {
      _lastOnlineTime = DateTime.fromMillisecondsSinceEpoch(onlineTimestamp);
    }
    if (syncTimestamp != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(syncTimestamp);
    }
  }

  /// Save last online time safely
  Future<void> _saveLastOnlineTime() async {
    if (_lastOnlineTime != null) {
      await _prefs.setInt(
        _lastOnlineKey,
        _lastOnlineTime!.millisecondsSinceEpoch,
      );
    }
  }

  /// Save last sync time safely
  Future<void> _saveLastSyncTime() async {
    if (_lastSyncTime != null) {
      await _prefs.setInt(
        _lastSyncKey,
        _lastSyncTime!.millisecondsSinceEpoch,
      );
    }
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

    // Complete with result
    void complete(bool result) {
      subscription?.cancel();
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    // Set up timeout
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
      cancelOnError: false,
    );

    return completer.future;
  }

  /// Cleanup resources safely
  Future<void> dispose() async {
    await stopMonitoring();

    // Close all stream controllers safely
    await Future.wait([
      _connectionStatusController.close(),
      _networkQualityController.close(),
      _onlineStatusController.close(),
      _syncStatusController.close(),
    ]);

    _isInitialized = false;

    if (kDebugMode) {
      print('🧹 ConnectivityManager disposed');
    }
  }
}

/// Bounded operation queue implementation
class BoundedOperationQueue {
  final int maxSize;
  final Queue<OfflineOperation> _queue = Queue<OfflineOperation>();
  final _lock = Lock();

  BoundedOperationQueue({required this.maxSize});

  bool get isEmpty => _queue.isEmpty;
  bool get isNotEmpty => _queue.isNotEmpty;
  int get length => _queue.length;

  Future<void> enqueue(OfflineOperation operation) async {
    await _lock.synchronized(() async {
      if (_queue.length >= maxSize) {
        throw QueueFullException();
      }
      _queue.add(operation);
      return;
    });
  }

  Future<OfflineOperation> dequeue() async {
    return await _lock.synchronized(() async {
      if (_queue.isEmpty) {
        throw QueueEmptyException();
      }
      return _queue.removeFirst();
    });
  }

  Future<void> clear() async {
    await _lock.synchronized(() async {
      _queue.clear();
      return;
    });
  }
}

/// Lock implementation for thread safety
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

/// Connection status enum with helper methods
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

  bool get isOnline =>
      this != ConnectionStatus.offline && this != ConnectionStatus.unknown;

  bool get isHighSpeed =>
      this == ConnectionStatus.wifi || this == ConnectionStatus.ethernet;

  bool get isLowSpeed =>
      this == ConnectionStatus.cellular || this == ConnectionStatus.bluetooth;

  bool get isMobile => this == ConnectionStatus.cellular;

  bool get isStable =>
      this == ConnectionStatus.wifi ||
      this == ConnectionStatus.ethernet ||
      this == ConnectionStatus.vpn;

  @override
  String toString() => value;
}

/// Network quality enum with helper methods
enum NetworkQuality {
  excellent('Excellent'),
  good('Good'),
  fair('Fair'),
  poor('Poor'),
  unknown('Unknown');

  final String value;
  const NetworkQuality(this.value);

  bool get isGoodEnough =>
      this == NetworkQuality.excellent || this == NetworkQuality.good;

  bool get needsImprovement =>
      this == NetworkQuality.fair || this == NetworkQuality.poor;

  bool get isUnusable => this == NetworkQuality.poor;

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

/// Custom exceptions
class QueueFullException implements Exception {
  @override
  String toString() => 'Operation queue is full';
}

class QueueEmptyException implements Exception {
  @override
  String toString() => 'Operation queue is empty';
}
