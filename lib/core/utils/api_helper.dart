// lib/core/utils/api_helper.dart

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

  /// Response metadata
  final Map<String, dynamic>? metadata;

  /// Constructor
  const ApiResponse({
    this.data,
    this.source,
    required this.status,
    this.error,
    this.message,
    this.metadata,
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
  CacheManager? _cache; // Make nullable

  // State management
  bool _isInitialized = false;
  bool _isDisposed = false;

  // Timeouts and retry configuration
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;

  /// Initialize API helper
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      debugPrint('🌐 ApiHelper: Starting initialization...');

      _monitoring = MonitoringManager();
      _connectivity = ConnectivityManager();

      // Try to get CacheManager if available
      try {
        debugPrint('🌐 ApiHelper: Initializing cache...');
        _cache = await CacheManager.initialize();
        debugPrint('✅ ApiHelper: Cache initialized');
      } catch (e) {
        debugPrint(
            '⚠️ ApiHelper: Cache not available, continuing without cache: $e');
        _cache = null;
      }

      _isInitialized = true;
      debugPrint('✅ ApiHelper fully initialized');
    } catch (e) {
      debugPrint('❌ ApiHelper initialization failed: $e');
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
      // Check network state and try cache
      if (!_connectivity.hasConnection) {
        final cached = await _getCachedResponse<T>(endpoint, parser);
        if (cached != null) {
          return ApiResponse(
            data: cached,
            source: DataSource.cache,
            status: ApiStatus.success,
            metadata: {'cached': true, 'offline': true},
          );
        }
        throw 'No network connection and no cached data available';
      }

      // Try cache if allowed and available
      if (!forceRefresh && useCache && _cache != null) {
        final cached = await _getCachedResponse<T>(endpoint, parser);
        if (cached != null) {
          return ApiResponse(
            data: cached,
            source: DataSource.cache,
            status: ApiStatus.success,
            metadata: {'cached': true},
          );
        }
      }

      // Execute network request
      final response = await _executeWithRetry(
        () =>
            _client.get(Uri.parse(endpoint), headers: headers).timeout(timeout),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final data = parser(jsonData);

        // Cache if available
        if (useCache && _cache != null) {
          await _cacheResponse(endpoint, jsonData);
        }

        return ApiResponse(
          data: data,
          source: DataSource.network,
          status: ApiStatus.success,
          metadata: {'statusCode': response.statusCode},
        );
      }

      throw _handleHttpError(response.statusCode);
    } catch (e) {
      _monitoring.logError(
        'API Request Failed',
        error: e,
        additionalData: {'endpoint': endpoint},
      );

      return ApiResponse(
        status: ApiStatus.error,
        error: e,
        message: e.toString(),
        metadata: {'endpoint': endpoint},
      );
    }
  }

  /// Get cached response with null safety
  Future<T?> _getCachedResponse<T>(
    String endpoint,
    T Function(Map<String, dynamic>) parser,
  ) async {
    if (_cache == null) {
      debugPrint('⚠️ ApiHelper: Cache not available, skipping cache check');
      return null;
    }

    try {
      final cached = await _cache?.get<Map<String, dynamic>>(endpoint);
      return cached != null ? parser(cached) : null;
    } catch (e) {
      _monitoring.logError('Cache read error', error: e);
      return null;
    }
  }

  /// Cache response data if cache available
  Future<void> _cacheResponse(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    if (_cache == null) {
      debugPrint('⚠️ ApiHelper: Cache not available, skipping cache write');
      return;
    }

    try {
      await _cache?.put(endpoint, data);
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
    debugPrint('🧹 ApiHelper disposed');
  }
}
