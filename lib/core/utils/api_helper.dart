// lib/core/utils/api_helper.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_paths.dart';
import './request_manager.dart';
import './connectivity_manager.dart';
import './sync_manager.dart';
import './cancellation_token.dart';
import './monitoring_manager.dart';

/// Enhanced ApiHelper with improved error handling, caching, and offline support
class ApiHelper {
  // Core components with proper initialization
  static final ApiHelper _instance = ApiHelper._internal();
  final _client = http.Client();
  final _requestManager = RequestManager();
  final _connectivityManager = ConnectivityManager();
  final _syncManager = SyncManager();
  final _monitoringManager = MonitoringManager();

  late final SharedPreferences _prefs;
  final _memoryCache = _LruCache<String, dynamic>(maxSize: 100);
  final _pendingRequests = <String, Completer<dynamic>>{};

  // State management
  bool _isInitialized = false;
  bool _isDisposed = false;

  // Constants
  static const Duration _defaultTimeout = Duration(seconds: 15);
  static const Duration _defaultCacheDuration = Duration(hours: 24);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  factory ApiHelper() => _instance;

  ApiHelper._internal();

  /// Initialize with required configurations
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize dependencies
      await Future.wait([
        _connectivityManager.initialize(),
        _syncManager.initialize(),
        _monitoringManager.initialize(),
      ]);

      _prefs = await SharedPreferences.getInstance();
      await _cleanExpiredCache();
      _isInitialized = true;

      if (kDebugMode) {
        print('✅ ApiHelper initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ApiHelper initialization failed: $e');
      }
      rethrow;
    }
  }

  /// Enhanced GET request with proper error handling and caching
  Future<ApiResponse<T>> get<T>({
    required String endpoint,
    required T Function(Map<String, dynamic>) parser,
    Map<String, String>? headers,
    bool forceRefresh = false,
    bool useCache = true,
    Duration timeout = _defaultTimeout,
    Duration cacheDuration = _defaultCacheDuration,
    int maxRetries = _maxRetries,
    CancellationToken? cancellationToken,
  }) async {
    _throwIfNotInitialized();

    final cacheKey = _generateCacheKey(endpoint);

    try {
      // Check connectivity first
      final isOffline = !await _connectivityManager.checkConnectivity();

      // Handle offline scenario with cache
      if (isOffline) {
        return await _handleOfflineRequest(
          cacheKey: cacheKey,
          parser: parser,
          endpoint: endpoint,
        );
      }

      // Check cache if appropriate
      if (!forceRefresh && useCache) {
        final cachedData = await _getCachedData(cacheKey);
        if (cachedData != null) {
          if (kDebugMode) {
            print('📦 Using cached data for: $endpoint');
          }
          return ApiResponse(
            data: parser(cachedData),
            source: DataSource.cache,
            status: ApiStatus.success,
          );
        }
      }

      // Queue request if same endpoint is pending
      if (_pendingRequests.containsKey(endpoint)) {
        final result = await _pendingRequests[endpoint]!.future;
        return ApiResponse(
          data: parser(result),
          source: DataSource.network,
          status: ApiStatus.success,
        );
      }

      // Execute request with retry logic
      return await _executeWithRetry(
        maxRetries: maxRetries,
        operation: () async {
          final completer = Completer<dynamic>();
          _pendingRequests[endpoint] = completer;

          try {
            // Execute request through RequestManager
            final response = await _requestManager.executeRequest(
              id: endpoint,
              request: () => _client
                  .get(
                    Uri.parse(endpoint),
                    headers: headers,
                  )
                  .timeout(timeout),
              cancellationToken: cancellationToken,
            );

            if (response.statusCode == 200) {
              final jsonData =
                  json.decode(response.body) as Map<String, dynamic>;

              // Cache successful response
              if (useCache) {
                await _cacheData(cacheKey, jsonData, cacheDuration);
              }

              completer.complete(jsonData);
              return ApiResponse(
                data: parser(jsonData),
                source: DataSource.network,
                status: ApiStatus.success,
              );
            } else {
              throw ApiException.fromStatusCode(response.statusCode);
            }
          } finally {
            _pendingRequests.remove(endpoint);
          }
        },
      );
    } on TimeoutException {
      return _handleTimeoutError(cacheKey, parser);
    } on SocketException {
      return _handleConnectionError(cacheKey, parser);
    } on ApiException catch (e) {
      return _handleApiError(e, cacheKey, parser);
    } catch (e) {
      return _handleUnexpectedError(e, cacheKey, parser);
    }
  }

  /// Handle offline request scenario
  Future<ApiResponse<T>> _handleOfflineRequest<T>({
    required String cacheKey,
    required T Function(Map<String, dynamic>) parser,
    required String endpoint,
  }) async {
    final cachedData = await _getCachedData(cacheKey);
    if (cachedData != null) {
      return ApiResponse(
        data: parser(cachedData),
        source: DataSource.cache,
        status: ApiStatus.success,
        message: 'Using cached data while offline',
      );
    }

    // Queue for sync when online
    _syncManager.addToSyncQueue(
      SyncOperation(
        id: endpoint,
        execute: () async {
          await get(
            endpoint: endpoint,
            parser: parser,
            forceRefresh: true,
          );
        },
      ),
    );

    throw const ApiException.noInternet();
  }

  /// Execute with retry logic
  Future<T> _executeWithRetry<T>({
    required Future<T> Function() operation,
    required int maxRetries,
  }) async {
    int attempts = 0;

    while (true) {
      try {
        attempts++;
        return await operation();
      } catch (e) {
        if (attempts >= maxRetries) rethrow;
        if (e is ApiException && !e.isRetryable) rethrow;

        await Future.delayed(_retryDelay * attempts);

        if (kDebugMode) {
          print('🔄 Retry attempt $attempts');
        }
      }
    }
  }

  /// Generate cache key
  String _generateCacheKey(String endpoint) {
    return 'api_cache_${endpoint.hashCode}';
  }

  /// Get cached data with validation
  Future<Map<String, dynamic>?> _getCachedData(String key) async {
    // Check memory cache first
    final memoryData = _memoryCache.get(key);
    if (memoryData != null) return memoryData;

    // Check disk cache
    try {
      final cachedJson = _prefs.getString(key);
      final timestampKey = '${key}_timestamp';
      final timestamp = _prefs.getInt(timestampKey);

      if (cachedJson != null && timestamp != null) {
        final cacheAge = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(timestamp),
        );

        if (cacheAge < _defaultCacheDuration) {
          final data = json.decode(cachedJson) as Map<String, dynamic>;
          _memoryCache.put(key, data);
          return data;
        } else {
          // Clean expired cache
          await Future.wait([
            _prefs.remove(key),
            _prefs.remove(timestampKey),
          ]);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Cache retrieval error: $e');
      }
    }

    return null;
  }

  /// Cache data with proper error handling
  Future<void> _cacheData(
    String key,
    Map<String, dynamic> data,
    Duration duration,
  ) async {
    try {
      // Memory cache
      _memoryCache.put(key, data);

      // Disk cache
      final jsonString = json.encode(data);
      await Future.wait([
        _prefs.setString(key, jsonString),
        _prefs.setInt(
          '${key}_timestamp',
          DateTime.now().millisecondsSinceEpoch,
        ),
      ]);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Cache storage error: $e');
      }
    }
  }

  /// Clean expired cache entries
  Future<void> _cleanExpiredCache() async {
    final now = DateTime.now();
    final keys = _prefs.getKeys().where((k) => k.startsWith('api_cache_'));

    for (final key in keys) {
      final timestamp = _prefs.getInt('${key}_timestamp');
      if (timestamp != null) {
        final age = now.difference(
          DateTime.fromMillisecondsSinceEpoch(timestamp),
        );

        if (age > _defaultCacheDuration) {
          await Future.wait([
            _prefs.remove(key),
            _prefs.remove('${key}_timestamp'),
          ]);
        }
      }
    }
  }

  /// Handle timeout errors
  Future<ApiResponse<T>> _handleTimeoutError<T>(
    String cacheKey,
    T Function(Map<String, dynamic>) parser,
  ) async {
    if (kDebugMode) {
      print('⌛ Request timeout');
    }

    final cachedData = await _getCachedData(cacheKey);
    if (cachedData != null) {
      return ApiResponse(
        data: parser(cachedData),
        source: DataSource.cache,
        status: ApiStatus.success,
        message: 'Using cached data due to timeout',
      );
    }

    return ApiResponse(
      status: ApiStatus.error,
      error: const ApiException.timeout(),
    );
  }

  /// Handle connection errors
  Future<ApiResponse<T>> _handleConnectionError<T>(
    String cacheKey,
    T Function(Map<String, dynamic>) parser,
  ) async {
    if (kDebugMode) {
      print('🌐 Connection error');
    }

    final cachedData = await _getCachedData(cacheKey);
    if (cachedData != null) {
      return ApiResponse(
        data: parser(cachedData),
        source: DataSource.cache,
        status: ApiStatus.success,
        message: 'Using cached data due to connection error',
      );
    }

    return ApiResponse(
      status: ApiStatus.error,
      error: const ApiException.noInternet(),
    );
  }

  /// Handle API errors
  Future<ApiResponse<T>> _handleApiError<T>(
    ApiException error,
    String cacheKey,
    T Function(Map<String, dynamic>) parser,
  ) async {
    if (kDebugMode) {
      print('🔴 API error: ${error.message}');
    }

    final cachedData = await _getCachedData(cacheKey);
    if (cachedData != null && error.shouldUseCachedData) {
      return ApiResponse(
        data: parser(cachedData),
        source: DataSource.cache,
        status: ApiStatus.success,
        message: 'Using cached data due to API error',
      );
    }

    return ApiResponse(
      status: ApiStatus.error,
      error: error,
    );
  }

  /// Handle unexpected errors
  Future<ApiResponse<T>> _handleUnexpectedError<T>(
    dynamic error,
    String cacheKey,
    T Function(Map<String, dynamic>) parser,
  ) async {
    if (kDebugMode) {
      print('❌ Unexpected error: $error');
    }

    final cachedData = await _getCachedData(cacheKey);
    if (cachedData != null) {
      return ApiResponse(
        data: parser(cachedData),
        source: DataSource.cache,
        status: ApiStatus.success,
        message: 'Using cached data due to unexpected error',
      );
    }

    return ApiResponse(
      status: ApiStatus.error,
      error: ApiException.unexpected(error),
    );
  }

  /// Clear specific cache entry
  Future<void> clearCache(String endpoint) async {
    final key = _generateCacheKey(endpoint);
    _memoryCache.remove(key);
    await Future.wait([
      _prefs.remove(key),
      _prefs.remove('${key}_timestamp'),
    ]);
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    _memoryCache.clear();
    final keys = _prefs.getKeys().where((k) => k.startsWith('api_cache_'));
    await Future.wait([
      for (final key in keys) ...[
        _prefs.remove(key),
        _prefs.remove('${key}_timestamp'),
      ],
    ]);
  }

  void _throwIfNotInitialized() {
    if (!_isInitialized) {
      throw StateError('ApiHelper not initialized');
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    _isDisposed = true;
    _client.close();
    _memoryCache.clear();
    _pendingRequests.clear();
    await _monitoringManager.dispose();
  }
}

/// LRU Cache implementation
class _LruCache<K, V> {
  final int maxSize;
  final _cache = <K, V>{};
  final _accessOrder = <K>[];

  _LruCache({required this.maxSize});

  V? get(K key) {
    final value = _cache[key];
    if (value != null) {
      _accessOrder.remove(key);
      _accessOrder.add(key);
    }
    return value;
  }

  void put(K key, V value) {
    if (_cache.length >= maxSize && !_cache.containsKey(key)) {
      // Remove least recently used
      final lru = _accessOrder.removeAt(0);
      _cache.remove(lru);
    }
    _cache[key] = value;
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }

  void remove(K key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }

  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }
}

/// API Response wrapper with proper typing
class ApiResponse<T> {
  final T? data;
  final DataSource? source;
  final ApiStatus status;
  final dynamic error;
  final String? message;

  const ApiResponse({
    this.data,
    this.source,
    required this.status,
    this.error,
    this.message,
  });

  bool get isSuccess => status == ApiStatus.success;
  bool get isError => status == ApiStatus.error;
  bool get isCached =>
      source == DataSource.cache || source == DataSource.memoryCache;
}

/// API Exception with proper error handling
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isRetryable;
  final bool shouldUseCachedData;

  const ApiException({
    required this.message,
    this.statusCode,
    this.isRetryable = true,
    this.shouldUseCachedData = true,
  });

  const ApiException.noInternet()
      : message = 'No internet connection',
        statusCode = null,
        isRetryable = true,
        shouldUseCachedData = true;

  const ApiException.timeout()
      : message = 'Request timed out',
        statusCode = null,
        isRetryable = true,
        shouldUseCachedData = true;

  const ApiException.serverError()
      : message = 'Server error occurred',
        statusCode = 500,
        isRetryable = true,
        shouldUseCachedData = true;

  const ApiException.invalidResponse()
      : message = 'Invalid response from server',
        statusCode = null,
        isRetryable = false,
        shouldUseCachedData = true;

  factory ApiException.fromStatusCode(int code) {
    final message = _getMessageForStatusCode(code);
    return ApiException(
      message: message,
      statusCode: code,
      isRetryable: code >= 500,
      shouldUseCachedData: code >= 500,
    );
  }

  factory ApiException.unexpected(dynamic error) {
    return ApiException(
      message: 'Unexpected error: ${error.toString()}',
      isRetryable: true,
      shouldUseCachedData: true,
    );
  }

  static String _getMessageForStatusCode(int statusCode) {
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
      case 502:
        return 'Bad gateway';
      case 503:
        return 'Service unavailable';
      default:
        return 'HTTP Error $statusCode';
    }
  }

  @override
  String toString() => 'ApiException: $message';
}

/// Data source enumeration
enum DataSource { network, cache, memoryCache }

/// API response status
enum ApiStatus { success, error }
