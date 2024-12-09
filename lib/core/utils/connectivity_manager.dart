import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rxdart/rxdart.dart';

/// A comprehensive connectivity manager that handles network state monitoring,
/// connection quality management, and offline state handling.
class ConnectivityManager {
  static final ConnectivityManager _instance = ConnectivityManager._internal();
  factory ConnectivityManager() => _instance;
  ConnectivityManager._internal();

  final Connectivity _connectivity = Connectivity();
  final BehaviorSubject<bool> _connectionStateController = BehaviorSubject<bool>();
  final BehaviorSubject<ConnectionQuality> _connectionQualityController = BehaviorSubject<ConnectionQuality>();
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _qualityCheckTimer;
  
  /// Stream of connection states (true = connected, false = disconnected)
  Stream<bool> get connectionState => _connectionStateController.stream;
  
  /// Stream of connection quality updates
  Stream<ConnectionQuality> get connectionQuality => _connectionQualityController.stream;
  
  /// Current connection state
  bool get isConnected => _connectionStateController.value;
  
  /// Current connection quality
  ConnectionQuality get currentQuality => _connectionQualityController.value;

  /// Initialize the connectivity manager
  Future<void> initialize() async {
    // Set initial states
    final initialState = await _connectivity.checkConnectivity();
    _updateConnectionState(initialState);
    _connectionQualityController.add(ConnectionQuality.unknown);
    
    // Start monitoring connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionState);
    
    // Start periodic quality checks
    _startQualityChecks();
  }

  /// Update the connection state based on connectivity result
  void _updateConnectionState(ConnectivityResult result) {
    final isConnected = result != ConnectivityResult.none;
    _connectionStateController.add(isConnected);
    
    // Trigger quality check on connection change
    if (isConnected) {
      _checkConnectionQuality();
    } else {
      _connectionQualityController.add(ConnectionQuality.none);
    }
  }

  /// Start periodic connection quality checks
  void _startQualityChecks() {
    _qualityCheckTimer?.cancel();
    _qualityCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkConnectionQuality(),
    );
  }

  /// Check connection quality by performing a speed test
  Future<void> _checkConnectionQuality() async {
    if (!_connectionStateController.value) {
      _connectionQualityController.add(ConnectionQuality.none);
      return;
    }

    try {
      final startTime = DateTime.now();
      final response = await _performSpeedTest();
      final duration = DateTime.now().difference(startTime);
      
      final quality = _calculateQuality(duration.inMilliseconds, response.length);
      _connectionQualityController.add(quality);
    } catch (e) {
      _connectionQualityController.add(ConnectionQuality.poor);
    }
  }

  /// Perform a basic speed test by downloading a small payload
  Future<String> _performSpeedTest() async {
    try {
      const testUrl = 'https://pokeapi.co/api/v2/pokemon/1';
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 5);
      
      final request = await httpClient.getUrl(Uri.parse(testUrl));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      return responseBody;
    } catch (e) {
      rethrow;
    }
  }

  /// Calculate connection quality based on response time and data size
  ConnectionQuality _calculateQuality(int responseTime, int dataSize) {
    final speedBps = (dataSize * 8) / (responseTime / 1000);
    
    if (responseTime < 300) return ConnectionQuality.excellent;
    if (responseTime < 1000) return ConnectionQuality.good;
    if (responseTime < 3000) return ConnectionQuality.fair;
    return ConnectionQuality.poor;
  }

  /// Force a manual connection quality check
  Future<void> checkQualityNow() => _checkConnectionQuality();

  /// Clean up resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _qualityCheckTimer?.cancel();
    _connectionStateController.close();
    _connectionQualityController.close();
  }
}

/// Represents different levels of connection quality
enum ConnectionQuality {
  none,
  unknown,
  poor,
  fair,
  good,
  excellent
}

/// Extension methods for ConnectionQuality
extension ConnectionQualityExt on ConnectionQuality {
  /// Get the recommended number of concurrent requests based on connection quality
  int get recommendedConcurrentRequests {
    switch (this) {
      case ConnectionQuality.excellent: return 5;
      case ConnectionQuality.good: return 3;
      case ConnectionQuality.fair: return 2;
      case ConnectionQuality.poor: return 1;
      default: return 1;
    }
  }

  /// Get the recommended cache duration based on connection quality
  Duration get recommendedCacheDuration {
    switch (this) {
      case ConnectionQuality.excellent: return const Duration(minutes: 30);
      case ConnectionQuality.good: return const Duration(hours: 1);
      case ConnectionQuality.fair: return const Duration(hours: 2);
      case ConnectionQuality.poor: return const Duration(hours: 4);
      default: return const Duration(hours: 24);
    }
  }
}