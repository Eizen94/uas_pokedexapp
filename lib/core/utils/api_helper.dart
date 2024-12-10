// lib/core/utils/api_helper.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import './request_manager.dart';
import './connectivity_manager.dart';
import './sync_manager.dart';
import './rate_limiter.dart';
import '../utils/prefs_helper.dart';

/// Enhanced API Helper optimized for Pokedex with smart caching and network handling
class ApiHelper {
  // Singleton implementation with thread safety
  static final ApiHelper _instance = ApiHelper._internal();

  // Core components
  final _client = http.Client();
  final _requestManager = RequestManager();
  final _connectivityManager = ConnectivityManager();
  final _syncManager = SyncManager();
  final _rateLimiter = RateLimiter();

  // Cache and state management
  late final SharedPreferences _prefs;
  final _memoryCache = _LruCache<String, dynamic>(maxSize: 100);
  final _pendingRequests = <String, Completer<dynamic>>{};
  final _downloadProgress = <String, double>{};

  // State flags
  bool _isInitialized = false;
  bool _isDisposed = false;

  // Constants
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const int _maxConcurrentRequests = 4;
  static const int _maxBatchSize = 20;

  factory ApiHelper() => _instance;
  ApiHelper._internal();

  // Getters
  bool get isInitialized => _isInitialized;

  /// Initialize with proper error handling and cleanup
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_isDisposed) {
      throw StateError('ApiHelper has been disposed');
    }

    try {
      _prefs = await PrefsHelper.instance.prefs;

      await Future.wait([
        _connectivityManager.initialize(),
        _syncManager.initialize(),
      ]);

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

  /// Enhanced GET request with smart caching and retry
  Future<ApiResponse<T>> get<T>({
    required String endpoint,
    required T Function(Map<String, dynamic>) parser,
    Map<String, String>? headers,
    bool forceRefresh = false,
    bool useCache = true,
    Duration timeout = const Duration(seconds: 10),
    Duration cacheDuration = const Duration(days: 7),
    bool allowBatching = false,
    bool isPriority = false,
  }) async {
    _throwIfNotInitialized();

    final cacheKey = _generateCacheKey(endpoint);

    try {
      // Check network status first
      final networkState = _connectivityManager.currentState;
      if (!networkState.isOnline) {
        return await _handleOfflineRequest(
          cacheKey: cacheKey,
          parser: parser,
          endpoint: endpoint,
        );
      }

      // Rate limiting check
      await _rateLimiter.checkLimit(endpoint);

      // Use cache for poor network conditions
      if (networkState.needsOptimization && useCache) {
        final cachedData = await _getCachedData(cacheKey);
        if (cachedData != null) {
          return ApiResponse(
            data: parser(cachedData),
            source: DataSource.cache,
            status: ApiStatus.success,
            message: 'Using cached data for poor network',
          );
        }
      }

      // Handle request batching for list endpoints
      if (allowBatching && _canBatchRequest(endpoint)) {
        return await _handleBatchedRequest(
          endpoint: endpoint,
          parser: parser,
          timeout: timeout,
          cacheDuration: cacheDuration,
        );
      }

      // Execute request with smart retry
      return await _executeWithRetry(
        maxRetries: _maxRetries,
        timeout: timeout,
        operation: () async {
          final response = await _executeRequest(
            endpoint: endpoint,
            headers: headers,
            timeout: timeout,
            isPriority: isPriority,
          );

          if (response.statusCode == 200) {
            final jsonData = json.decode(response.body) as Map<String, dynamic>;

            // Cache successful response
            if (useCache) {
              await _cacheData(cacheKey, jsonData, cacheDuration);
            }

            return ApiResponse(
              data: parser(jsonData),
              source: DataSource.network,
              status: ApiStatus.success,
            );
          } else {
            throw ApiException.fromStatusCode(response.statusCode);
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

  /// Execute request with proper resource management
  Future<http.Response> _executeRequest({
    required String endpoint,
    Map<String, String>? headers,
    required Duration timeout,
    bool isPriority = false,
  }) async {
    final completer = Completer<http.Response>();

    // Handle concurrent request limits
    if (_pendingRequests.length >= _maxConcurrentRequests && !isPriority) {
      await _waitForSlot();
    }

    _pendingRequests[endpoint] = completer;

    try {
      final response = await _requestManager.executeRequest(
        id: endpoint,
        request: () =>
            _client.get(Uri.parse(endpoint), headers: headers).timeout(timeout),
      );

      completer.complete(response);
      return response;
    } finally {
      _pendingRequests.remove(endpoint);
    }
  }

  /// Execute with smart retry based on network conditions
  Future<T> _executeWithRetry<T>({
    required Future<T> Function() operation,
    required int maxRetries,
    required Duration timeout,
  }) async {
    int attempts = 0;
    Duration currentDelay = _retryDelay;

    while (true) {
      try {
        attempts++;
        return await operation();
      } catch (e) {
        if (attempts >= maxRetries) rethrow;
        if (e is ApiException && !e.isRetryable) rethrow;

        // Adjust retry delay based on network quality
        if (_connectivityManager.currentState.needsOptimization) {
          currentDelay *= 2;
        }

        await Future.delayed(currentDelay);

        if (kDebugMode) {
          print(
              '🔄 Retry attempt $attempts with delay ${currentDelay.inSeconds}s');
        }
      }
    }
  }

  /// Handle offline scenario with smart caching
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
    await _syncManager.queueOfflineOperation(endpoint);

    throw const ApiException.noInternet();
  }

  /// Smart caching system with compression
  Future<void> _cacheData(
    String key,
    Map<String, dynamic> data,
    Duration duration,
  ) async {
    try {
      // Memory cache
      _memoryCache.put(key, data);

      // Compress data if large
      final jsonString = json.encode(data);
      final compressed = jsonString.length > 1000 * 1024; // 1MB threshold
      final List<int> storageData = compressed
          ? gzip.encode(utf8.encode(jsonString))
          : utf8.encode(jsonString);

      await Future.wait([
        _prefs.setString(key, base64Encode(storageData)),
        _prefs.setInt(
          '${key}_timestamp',
          DateTime.now().millisecondsSinceEpoch,
        ),
        if (compressed) _prefs.setBool('${key}_compressed', true),
      ]);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Cache storage error: $e');
      }
    }
  }

  /// Get cached data with compression handling
  Future<Map<String, dynamic>?> _getCachedData(String key) async {
    // Check memory cache first
    final memoryData = _memoryCache.get(key);
    if (memoryData != null) return memoryData;

    try {
      final cachedData = _prefs.getString(key);
      final timestamp = _prefs.getInt('${key}_timestamp');
      final isCompressed = _prefs.getBool('${key}_compressed') ?? false;

      if (cachedData != null && timestamp != null) {
        final age = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(timestamp),
        );

        if (age < const Duration(days: 1)) {
          final decodedData = base64Decode(cachedData);
          final jsonString = isCompressed
              ? utf8.decode(gzip.decode(decodedData))
              : utf8.decode(decodedData);

          final data = json.decode(jsonString) as Map<String, dynamic>;
          _memoryCache.put(key, data);
          return data;
        } else {
          await _removeCache(key);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Cache retrieval error: $e');
      }
    }
    return null;
  }

  /// Handle batch requests efficiently
  Future<ApiResponse<T>> _handleBatchedRequest<T>({
    required String endpoint,
    required T Function(Map<String, dynamic>) parser,
    required Duration timeout,
    required Duration cacheDuration,
  }) async {
    final batchKey = _getBatchKey(endpoint);

    if (_pendingRequests.containsKey(batchKey)) {
      final result = await _pendingRequests[batchKey]!.future;
      return ApiResponse(
        data: parser(result as Map<String, dynamic>),
        source: DataSource.network,
        status: ApiStatus.success,
      );
    }

    final completer = Completer<dynamic>();
    _pendingRequests[batchKey] = completer;

    try {
      final responses = await Future.wait(
        _getBatchedEndpoints(endpoint).map(
          (e) => _executeRequest(endpoint: e, timeout: timeout),
        ),
      );

      final combinedData = _combineBatchResponses(responses);
      completer.complete(combinedData);

      return ApiResponse(
        data: parser(combinedData),
        source: DataSource.network,
        status: ApiStatus.success,
      );
    } finally {
      _pendingRequests.remove(batchKey);
    }
  }

  /// Resource cleanup
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _client.close();
    _memoryCache.clear();
    _pendingRequests.clear();
    _downloadProgress.clear();

    await _rateLimiter.dispose();
  }

  void _throwIfNotInitialized() {
    if (_isDisposed) {
      throw StateError('ApiHelper has been disposed');
    }
    if (!_isInitialized) {
      throw StateError('ApiHelper not initialized');
    }
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
      final lru = _accessOrder.removeAt(0);
      _cache.remove(lru);
    }
    _cache[key] = value;
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }

  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }
}

/// API Response wrapper with proper type safety
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
  bool get isCached => source == DataSource.cache;
}

/// Typed enums for better type safety
enum DataSource { network, cache }

enum ApiStatus { success, error }

/// Custom exceptions with proper error handling
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isRetryable;

  const ApiException({
    required this.message,
    this.statusCode,
    this.isRetryable = true,
  });

  factory ApiException.fromStatusCode(int code) {
    final message = _getMessageForStatusCode(code);
    return ApiException(
      message: message,
      statusCode: code,
      isRetryable: code >= 500,
    );
  }

  static String _getMessageForStatusCode(int code) {
    switch (code) {
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
        return 'HTTP Error $code';
    }
  }

  @override
  String toString() => 'ApiException: $message';
}
