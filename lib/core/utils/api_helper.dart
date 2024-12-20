// lib/core/utils/api_helper.dart

/// API helper utility for handling HTTP requests with caching.
/// Provides centralized API access with error handling and caching support.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'monitoring_manager.dart';
import 'connectivity_manager.dart';
import 'cache_manager.dart';

/// API Response wrapper with type safety
class ApiResponse<T> {
  /// Response data
  final T? data;

  /// Response source (cache/network)
  final DataSource? source;

  /// Response status
  final ApiStatus status;

  /// Error if any
  final dynamic error;

  /// Error message if any
  final String? message;

  /// Constructor
  const ApiResponse({
    this.data,
    this.source,
    required this.status,
    this.error,
    this.message,
  });

  /// Whether response is successful
  bool get isSuccess => status == ApiStatus.success;

  /// Whether response has error
  bool get isError => status == ApiStatus.error;

  /// Whether response is from cache
  bool get isCached => source == DataSource.cache;
}

/// Data source enum
enum DataSource {
  /// Data from network
  network,

  /// Data from cache
  cache,
}

/// API status enum
enum ApiStatus {
  /// Success status
  success,

  /// Error status
  error,
}

/// API Helper class
class ApiHelper {
  // Singleton implementation
  static final ApiHelper _instance = ApiHelper._internal();
  factory ApiHelper() => _instance;
  ApiHelper._internal();

  // Core dependencies
  final _client = http.Client();
  late final MonitoringManager _monitoring;
  late final ConnectivityManager _connectivity;
  CacheManager? _cache;

  // State management
  bool _isInitialized = false;
  bool _isDisposed = false;
  final _initCompleter = Completer<void>();

  // Timeouts and retry configuration
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;

  /// Initialize API helper
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      _monitoring = MonitoringManager();
      _connectivity = ConnectivityManager();
      _cache = await CacheManager.initialize();

      _isInitialized = true;
      _initCompleter.complete();

      if (kDebugMode) {
        print('✅ ApiHelper initialized');
      }
    } catch (e) {
      _initCompleter.completeError(e);
      if (kDebugMode) {
        print('❌ ApiHelper initialization failed: $e');
      }
      rethrow;
    }
  }

  /// Execute GET request with caching
  Future<ApiResponse<T>> get<T>({
    required String endpoint,
    required T Function(Map<String, dynamic>) parser,
    Map<String, String>? headers,
    bool forceRefresh = false,
    bool useCache = true,
    Duration timeout = _defaultTimeout,
  }) async {
    _throwIfNotInitialized();

    try {
      // Check network state
      if (!_connectivity.hasConnection) {
        final cached = await _getCachedResponse<T>(endpoint, parser);
        if (cached != null) {
          return ApiResponse(
            data: cached,
            source: DataSource.cache,
            status: ApiStatus.success,
          );
        }
        throw 'No network connection and no cached data available';
      }

      // Try to get from cache if allowed
      if (!forceRefresh && useCache) {
        final cached = await _getCachedResponse<T>(endpoint, parser);
        if (cached != null) {
          return ApiResponse(
            data: cached,
            source: DataSource.cache,
            status: ApiStatus.success,
          );
        }
      }

      // Execute network request with retry
      final response = await _executeWithRetry(
        () => _client
            .get(
              Uri.parse(endpoint),
              headers: headers,
            )
            .timeout(timeout),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final data = parser(jsonData);

        // Cache successful response
        if (useCache) {
          await _cacheResponse(endpoint, jsonData);
        }

        return ApiResponse(
          data: data,
          source: DataSource.network,
          status: ApiStatus.success,
        );
      }

      throw _handleHttpError(response.statusCode);
    } catch (e) {
      return ApiResponse(
        status: ApiStatus.error,
        error: e,
        message: e.toString(),
      );
    }
  }

  /// Get cached response
  Future<T?> _getCachedResponse<T>(
    String endpoint,
    T Function(Map<String, dynamic>) parser,
  ) async {
    try {
      final cached = await _cache.get<Map<String, dynamic>>(endpoint);
      return cached != null ? parser(cached) : null;
    } catch (e) {
      _monitoring.logError('Cache read error', error: e);
      return null;
    }
  }

  /// Cache response data
  Future<void> _cacheResponse(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      await _cache.put(endpoint, data);
    } catch (e) {
      _monitoring.logError('Cache write error', error: e);
    }
  }

  /// Execute request with retry logic
  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() request,
  ) async {
    int attempts = 0;
    while (attempts < _maxRetries) {
      try {
        return await request();
      } catch (e) {
        attempts++;
        if (attempts == _maxRetries) rethrow;
        await Future.delayed(Duration(seconds: attempts));
      }
    }
    throw Exception('Max retry attempts reached');
  }

  /// Handle HTTP error codes
  String _handleHttpError(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not found';
      case 429:
        return 'Too many requests';
      case 500:
        return 'Internal server error';
      default:
        return 'HTTP Error $statusCode';
    }
  }

  /// Check initialization status
  void _throwIfNotInitialized() {
    if (_isDisposed) {
      throw StateError('ApiHelper has been disposed');
    }
    if (!_isInitialized) {
      throw StateError('ApiHelper not initialized');
    }
  }

  /// Cleanup resources
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    _client.close();

    if (kDebugMode) {
      print('🧹 ApiHelper disposed');
    }
  }
}
