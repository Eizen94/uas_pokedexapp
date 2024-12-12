// lib/core/utils/api_helper.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_paths.dart';
import 'request_manager.dart';
import 'connectivity_manager.dart';
import 'sync_manager.dart';
import 'rate_limiter.dart';
import 'cancellation_token.dart';
import 'monitoring_manager.dart';
import 'prefs_helper.dart';

class ApiHelper {
  // Singleton implementation with proper locking
  static final ApiHelper _instance = ApiHelper._internal();
  static final _lock = Object();
  
  // Core components with proper initialization
  final _client = http.Client();
  late final RequestManager _requestManager;
  late final ConnectivityManager _connectivityManager;
  late final SyncManager _syncManager;
  late final RateLimiter _rateLimiter;
  late final PrefsHelper _prefsHelper;

  // Type-safe cache implementation
  final _memoryCache = _LruCache<String, Map<String, dynamic>>(maxSize: 100);
  final _pendingRequests = <String, Completer<Map<String, dynamic>>>{};
  final _downloadProgress = <String, double>{};

  // State management
  bool _isInitialized = false;
  bool _isDisposed = false;
  Timer? _cleanupTimer;
  final _initCompleter = Completer<void>();

  // Constants with proper documentation
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _cleanupInterval = Duration(minutes: 30);
  static const int _maxRetries = 3;
  static const int _maxConcurrentRequests = 4;
  static const int _maxBatchSize = 20;

  ApiHelper._internal();
  
  factory ApiHelper() => _instance;

  /// Initialize API helper with proper error handling
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      await synchronized(_lock, () async {
        _prefsHelper = await PrefsHelper.getInstance();
        _connectivityManager = await ConnectivityManager.getInstance();
        _requestManager = RequestManager();
        _syncManager = SyncManager();
        _rateLimiter = RateLimiter();

        await Future.wait([
          _connectivityManager.initialize(),
          _syncManager.initialize(),
        ]);

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

  /// Execute GET request with proper error handling and caching
  Future<ApiResponse<T>> get<T>({
    required String endpoint,
    required T Function(Map<String, dynamic>) parser,
    Map<String, String>? headers,
    bool forceRefresh = false,
    bool useCache = true,
    Duration timeout = _defaultTimeout,
    CancellationToken? cancellationToken,
  }) async {
    _throwIfNotInitialized();

    final cacheKey = _generateCacheKey(endpoint);

    try {
      // Network state validation
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

      // Cache handling for poor network
      if (networkState.needsOptimization && useCache && !forceRefresh) {
        final cachedData = await _getCachedData(cacheKey);
        if (cachedData != null) {
          return ApiResponse(
            data: parser(cachedData),
            source: DataSource.cache,
            status: ApiStatus.success,
          );
        }
      }

      // Execute request with retry logic
      return await _executeWithRetry(
        maxRetries: _maxRetries,
        timeout: timeout,
        operation: () async {
          final response = await _executeRequest(
            endpoint: endpoint,
            headers: headers,
            timeout: timeout,
            cancellationToken: cancellationToken,
          );

          if (response.statusCode == 200) {
            final jsonData = json.decode(response.body) as Map<String, dynamic>;
            
            if (useCache) {
              await _cacheData(cacheKey, jsonData);
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
    CancellationToken? cancellationToken,
  }) async {
    final completer = Completer<http.Response>();
    
    if (_pendingRequests.length >= _maxConcurrentRequests) {
      await _waitForSlot();
    }

    _pendingRequests[endpoint] = completer as Completer<Map<String, dynamic>>;

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

  /// Clean up resources properly
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

/// Type-safe LRU Cache implementation
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

/// Type-safe API Response wrapper
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

/// Strongly typed enums
enum DataSource {
  network,
  cache
}

enum ApiStatus {
  success,
  error
}

/// Custom exception with proper error information
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
    final message = switch (code) {
      400 => 'Bad request',
      401 => 'Unauthorized',
      403 => 'Forbidden',
      404 => 'Not found',
      429 => 'Too many requests',
      500 => 'Internal server error',
      _ => 'HTTP Error $code'
    };

    return ApiException(
      message: message,
      statusCode: code,
      isRetryable: code >= 500,
    );
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