//lib/core/utils/api_helper.dart

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

/// Enhanced ApiHelper optimized for Pokedex with smart caching and network handling
class ApiHelper {
  // Core components with proper initialization
  static final ApiHelper _instance = ApiHelper._internal();
  final _client = http.Client();
  final _requestManager = RequestManager();
  final _connectivityManager = ConnectivityManager();
  final _syncManager = SyncManager();
  
  late final SharedPreferences _prefs;
  final _memoryCache = _LruCache<String, dynamic>(maxSize: 100);
  final _pendingRequests = <String, Completer<dynamic>>{};
  final _downloadProgress = <String, double>{};
  
  // State management
  bool _isInitialized = false;
  bool _isDisposed = false;

  // Pokemon-specific settings
  static const Duration _listTimeout = Duration(seconds: 15);
  static const Duration _detailTimeout = Duration(seconds: 10);
  static const Duration _evolutionTimeout = Duration(seconds: 8);
  static const Duration _defaultCacheDuration = Duration(days: 7); // Pokemon data rarely changes
  static const Duration _listCacheDuration = Duration(hours: 24);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const int _maxConcurrentRequests = 4;
  static const int _maxBatchSize = 20;
  
  factory ApiHelper() => _instance;
  ApiHelper._internal();

  /// Initialize with proper configuration and error handling
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize core components in parallel
      await Future.wait([
        _connectivityManager.initialize(),
        _syncManager.initialize(),
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

  /// Enhanced GET request with smart timeouts and caching
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
    timeout = _getTimeoutForEndpoint(endpoint);
    cacheDuration = _getCacheDurationForEndpoint(endpoint);

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

      // Check cache if appropriate
      if (!forceRefresh && useCache) {
        final cachedData = await _getCachedData(cacheKey);
        if (cachedData != null) {
          // Preemptively refresh cache if network is good
          if (networkState.isHighSpeed) {
            _refreshCacheAsync(endpoint, cacheKey, cacheDuration);
          }
          return ApiResponse(
            data: parser(cachedData),
            source: DataSource.cache,
            status: ApiStatus.success,
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

      // Execute request with optimized retry logic
      return await _executeWithSmartRetry(
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

            // Cache successful response with proper duration
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

  /// Get appropriate timeout based on endpoint type
  Duration _getTimeoutForEndpoint(String endpoint) {
    if (endpoint.contains('pokemon-species')) {
      return _evolutionTimeout;
    } else if (endpoint.contains('pokemon/') && endpoint.contains('?')) {
      return _listTimeout;
    } else if (endpoint.contains('pokemon/')) {
      return _detailTimeout;
    } else {
      return _detailTimeout;
    }
  }

  /// Get appropriate cache duration based on endpoint
  Duration _getCacheDurationForEndpoint(String endpoint) {
    if (endpoint.contains('?')) { // List endpoints
      return _listCacheDuration;
    } else {
      return _defaultCacheDuration; // Pokemon details rarely change
    }
  }

  /// Execute HTTP request with proper error handling
  Future<http.Response> _executeRequest({
    required String endpoint,
    Map<String, String>? headers,
    required Duration timeout,
    bool isPriority = false,
  }) async {
    final completer = Completer<http.Response>();
    
    if (_pendingRequests.length >= _maxConcurrentRequests && !isPriority) {
      await _waitForSlot();
    }
    
    _pendingRequests[endpoint] = completer;

    try {
      final response = await _requestManager.executeRequest(
        id: endpoint,
        request: () => _client.get(
          Uri.parse(endpoint),
          headers: headers,
        ).timeout(timeout),
      );
      
      completer.complete(response);
      return response;
    } finally {
      _pendingRequests.remove(endpoint);
    }
  }

  /// Wait for request slot with timeout
  Future<void> _waitForSlot() async {
    var waitTime = Duration.zero;
    final maxWait = const Duration(seconds: 30);
    
    while (_pendingRequests.length >= _maxConcurrentRequests) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitTime += const Duration(milliseconds: 100);
      
      if (waitTime >= maxWait) {
        throw const ApiException(
          message: 'Request queue timeout',
          isRetryable: true,
        );
      }
    }
  }

  /// Execute with smart retry based on network conditions
  Future<T> _executeWithSmartRetry<T>({
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
          print('🔄 Retry attempt $attempts with delay ${currentDelay.inSeconds}s');
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

    // Queue for sync when online if not already queued
    await _syncManager.queueOfflineOperation(endpoint);

    throw const ApiException.noInternet();
  }

  /// Smart caching system with compression for large responses
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

        if (age < _defaultCacheDuration) {
          final decodedData = base64Decode(cachedData);
          final jsonString = isCompressed 
            ? utf8.decode(gzip.decode(decodedData))
            : utf8.decode(decodedData);

          final data = json.decode(jsonString) as Map<String, dynamic>;
          _memoryCache.put(key, data);
          return data;
        } else {
          await Future.wait([
            _prefs.remove(key),
            _prefs.remove('${key}_timestamp'),
            _prefs.remove('${key}_compressed'),
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

  /// Clean expired cache with batching
  Future<void> _cleanExpiredCache() async {
    final now = DateTime.now();
    final keys = _prefs.getKeys().where((k) => k.startsWith('api_cache_'));
    final batchSize = 50;
    
    for (var i = 0; i < keys.length; i += batchSize) {
      final batch = keys.skip(i).take(batchSize);
      await Future.wait(
        batch.map((key) async {
          final timestamp = _prefs.getInt('${key}_timestamp');
          if (timestamp != null) {
            final age = now.difference(
              DateTime.fromMillisecondsSinceEpoch(timestamp),
            );
            
            if (age > _defaultCacheDuration) {
              await Future.wait([
                _prefs.remove(key),
                _prefs.remove('${key}_timestamp'),
                _prefs.remove('${key}_compressed'),
              ]);
            }
          }
        }),
      );
    }
  }

  /// Handle batched requests for list endpoints
  Future<ApiResponse<T>> _handleBatchedRequest<T>({
    required String endpoint,
    required T Function(Map<String, dynamic>) parser,
    required Duration timeout,
    required Duration cacheDuration,
  }) async {
    final batchKey = _getBatchKey(endpoint);
    
    // Wait for existing batch
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
      final batchedEndpoints = _getBatchedEndpoints(endpoint);
      final responses = await Future.wait(
        batchedEndpoints.map((e) => _executeRequest(
          endpoint: e,
          timeout: timeout,
        )),
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

  /// Get key for batch request
  String _getBatchKey(String endpoint) {
    return 'batch_${endpoint.split('?').first}';
  }

  /// Check if request can be batched
  /// 