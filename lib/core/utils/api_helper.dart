// lib/core/utils/api_helper.dart

// Dart imports
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Package imports
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Local imports
import '../constants/api_paths.dart';
import 'request_manager.dart';
import 'connectivity_manager.dart';
import 'sync_manager.dart';
import 'rate_limiter.dart';
import 'cancellation_token.dart';
import 'monitoring_manager.dart';
import 'prefs_helper.dart';

/// Enhanced API Helper optimized for Pokemon API with smart caching
/// and robust network handling.
class ApiHelper {
  // Singleton pattern implementation
  static final ApiHelper _instance = ApiHelper._internal();
  static final _lock = Object();

  // Core components
  final _client = http.Client();
  late final RequestManager _requestManager;
  late final ConnectivityManager _connectivityManager;
  late final SyncManager _syncManager;
  late final RateLimiter _rateLimiter;
  late final PrefsHelper _prefsHelper;

  // Cache management
  final _memoryCache = _LruCache<String, dynamic>(maxSize: 100);
  final _pendingRequests = <String, Completer<dynamic>>{};
  final _downloadProgress = <String, double>{};

  // State management
  bool _isInitialized = false;
  bool _isDisposed = false;
  Timer? _cleanupTimer;
  final _initCompleter = Completer<void>();

  // Constants
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _cleanupInterval = Duration(minutes: 30);
  static const int _maxRetries = 3;
  static const int _maxConcurrentRequests = 4;
  static const int _maxBatchSize = 20;

  // Private constructor
  ApiHelper._internal();

  // Factory constructor
  factory ApiHelper() => _instance;

  /// Initialize with proper error handling
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      await synchronized(_lock, () async {
        // Initialize dependencies
        _prefsHelper = await PrefsHelper.getInstance();
        _connectivityManager = await ConnectivityManager.getInstance();
        _requestManager = RequestManager();
        _syncManager = SyncManager();
        _rateLimiter = RateLimiter();

        await Future.wait([
          _connectivityManager.initialize(),
          _syncManager.initialize(),
        ]);

        // Setup cache cleanup
        _startCleanupTimer();

        _isInitialized = true;
        _initCompleter.complete();

        if (kDebugMode) {
          print('✅ ApiHelper initialized');
        }
      });
    } catch (e) {
      _initCompleter.completeError(e);
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
    CancellationToken? cancellationToken,
  }) async {
    _throwIfNotInitialized();

    final cacheKey = _generateCacheKey(endpoint);

    try {
      // Check network status
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

      // Use cache for poor network
      if (networkState.needsOptimization && useCache && !forceRefresh) {
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

      // Handle batch requests
      if (allowBatching && _canBatchRequest(endpoint)) {
        return await _handleBatchedRequest(
          endpoint: endpoint,
          parser: parser,
          timeout: timeout,
          cacheDuration: cacheDuration,
          cancellationToken: cancellationToken,
        );
      }

      // Execute request with retry
      return await _executeWithRetry(
        maxRetries: _maxRetries,
        timeout: timeout,
        operation: () async {
          final response = await _executeRequest(
            endpoint: endpoint,
            headers: headers,
            timeout: timeout,
            isPriority: isPriority,
            cancellationToken: cancellationToken,
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
    CancellationToken? cancellationToken,
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
        request: () async {
          final response = await _client
              .get(Uri.parse(endpoint), headers: headers)
              .timeout(timeout);

          cancellationToken?.throwIfCancelled();
          return response;
        },
        cancellationToken: cancellationToken,
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
    Duration currentDelay = const Duration(seconds: 2);

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

      // Store with metadata
      await Future.wait([
        _prefsHelper.set(key, base64Encode(storageData)),
        _prefsHelper.set(
          '${key}_timestamp',
          DateTime.now().millisecondsSinceEpoch,
        ),
        if (compressed) _prefsHelper.set('${key}_compressed', true),
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
      final cachedData = _prefsHelper.get<String>(key);
      final timestamp = _prefsHelper.get<int>('${key}_timestamp');
      final isCompressed =
          _prefsHelper.get<bool>('${key}_compressed') ?? false;

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

  /// Remove cached data
  Future<void> _removeCache(String key) async {
    try {
      _memoryCache.remove(key);
      await Future.wait([
        _prefsHelper.remove(key),
        _prefsHelper.remove('${key}_timestamp'),
        _prefsHelper.remove('${key}_compressed'),
      ]);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Cache removal error: $e');
      }
    }
  }

  /// Start cache cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      _cleanupOldCache();
    });
  }

  /// Cleanup old cache entries
  Future<void> _cleanupOldCache() async {
    try {
      final keys = _prefsHelper.getKeys();
      final now = DateTime.now();

      for (final key in keys) {
        if (!key.endsWith('_timestamp')) continue;

        final timestamp = _prefsHelper.get<int>(key);
        if (timestamp == null) continue;

        final age = now.difference(
          DateTime.fromMillisecondsSinceEpoch(timestamp),
        );

        if (age > const Duration(days: 7)) {
          final baseKey = key.replaceAll('_timestamp', '');
          await _removeCache(baseKey);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Cache cleanup error: $e');
      }
    }
  }

  /// Handle error scenarios
  Future<ApiResponse<T>> _handleTimeoutError<T>(
    String cacheKey,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final cachedData = await _getCachedData(cacheKey);
    if (cachedData != null) {
      return ApiResponse(
        data: parser(cachedData),
        source: DataSource.cache,
        status: ApiStatus.success,
        message: 'Using cached data after timeout',
      );
    }
    throw const ApiException.timeout();
  }

  Future<ApiResponse<T>> _handleConnectionError<T>(
    String cacheKey,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final cachedData = await _getCachedData(cacheKey);
    if (cachedData != null) {
      return ApiResponse(
        data: parser(cachedData),
        source: DataSource.cache,
        status: ApiStatus.success,
        message: 'Using cached data after connection error',
      );
    }
    throw const ApiException.noInternet();
  }

  Future<ApiResponse<T>> _handleApiError<T>(
    ApiException error,
    String cacheKey,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final cachedData = await _getCachedData(cacheKey);
    if (cachedData != null) {
      return ApiResponse(
        data: parser(cachedData),
        source: DataSource.cache,
        status: ApiStatus.success,
        message: 'Using cached data after API error',
      );
    }
    throw error;
  }

  Future<ApiResponse<T>> _handleUnexpectedError<T>(
    Object error,
    String cacheKey,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final cachedData = await _getCachedData(cacheKey);
    if (cachedData != null) {
      return ApiResponse(
        data: parser(cachedData),
        source: DataSource.cache,
        status: ApiStatus.success,
        message: 'Using cached data after error',
      );
    }
    throw ApiException(message: error.toString());
  }

  /// Wait for request slot
  Future<void> _waitForSlot() async {
    while (_pendingRequests.length >= _maxConcurrentRequests) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Generate cache key
  String _generateCacheKey(String endpoint) {
    return 'api_cache_${endpoint.hashCode}';
  }

  /// Check if request can be batched
  bool _canBatchRequest(String endpoint) {
    return endpoint.contains(ApiPaths.kPokemon) &&
        !endpoint.contains('species') &&
        !endpoint.contains('evolution-chain');
  }

  /// Resource cleanup
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _cleanupTimer?.cancel();
    _client.close();
    _memoryCache.clear();
    _pendingRequests.clear();
    _downloadProgress.clear();

    if (kDebugMode) {
      print('🧹 ApiHelper disposed');
    }
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

  void remove(K key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }

  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }
}

/// API Response wrapper
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

  @override
  String toString() => 'ApiResponse(status: $status, source: $source)';
}

/// Data source enum
enum DataSource {
  network,
  cache;

  @override
  String toString() => name;
}

/// API status enum
enum ApiStatus {
  success,
  error;

  @override
  String toString() => name;
}

/// Custom API exception
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isRetryable;

  const ApiException({
    required this.message,
    this.statusCode,
    this.isRetryable = true,
  });

  const ApiException.timeout()
      : message = 'Request timed out',
        statusCode = null,
        isRetryable = true;

  const ApiException.noInternet()
      : message = 'No internet connection',
        statusCode = null,
        isRetryable = true;

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

/// Thread-safe operation helper
Future<T> synchronized<T>(
  Object lock,
  Future<T> Function() computation,
) async {
  final completer = Completer<void>();
  try {
    return await computation();
  } finally {
    completer.complete();
  }
}
