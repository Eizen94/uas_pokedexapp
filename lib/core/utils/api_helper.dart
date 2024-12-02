// lib/core/utils/api_helper.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiHelper {
  static final ApiHelper _instance = ApiHelper._internal();
  final http.Client _client = http.Client();
  late final SharedPreferences _prefs;
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Constants
  static const Duration defaultTimeout = Duration(seconds: 15);
  static const Duration cacheDuration = Duration(hours: 24);

  // Cache size limits
  static const int maxMemoryCacheItems = 100;
  static const int maxDiskCacheSize = 50 * 1024 * 1024; // 50MB

  factory ApiHelper() => _instance;

  ApiHelper._internal();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _cleanOldCache();
  }

  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? headers,
    bool forceRefresh = false,
    bool useCache = true,
    Duration timeout = defaultTimeout,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    try {
      // Check connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOffline = connectivityResult == ConnectivityResult.none;

      // Handle offline scenario
      if (isOffline) {
        final cachedData = await _getCachedData(endpoint);
        if (cachedData != null) {
          if (kDebugMode) {
            print('📦 Using offline cached data for: $endpoint');
          }
          return ApiResponse(
            data: parser(cachedData),
            source: DataSource.cache,
            status: ApiStatus.success,
          );
        }
        throw const NoInternetException();
      }

      // Check memory cache if not forcing refresh
      if (!forceRefresh && useCache && _hasValidMemoryCache(endpoint)) {
        if (kDebugMode) {
          print('💾 Using memory cache for: $endpoint');
        }
        return ApiResponse(
          data: parser(_memoryCache[endpoint]),
          source: DataSource.memoryCache,
          status: ApiStatus.success,
        );
      }

      // Make network request
      final response = await _client
          .get(Uri.parse(endpoint), headers: headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;

        // Cache successful response
        if (useCache) {
          await _cacheData(endpoint, jsonData);
        }

        return ApiResponse(
          data: parser(jsonData),
          source: DataSource.network,
          status: ApiStatus.success,
        );
      } else {
        throw HttpException('Server error: ${response.statusCode}');
      }
    } on TimeoutException {
      return _handleTimeoutError(endpoint, parser);
    } on SocketException {
      return _handleConnectionError(endpoint, parser);
    } catch (e) {
      return _handleGeneralError(e, endpoint, parser);
    }
  }

  Future<ApiResponse<T>> _handleTimeoutError<T>(
    String endpoint,
    T Function(Map<String, dynamic>) parser,
  ) async {
    if (kDebugMode) {
      print('⌛ Request timeout for: $endpoint');
    }
    final cachedData = await _getCachedData(endpoint);
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
      error: TimeoutException('Request timed out'),
    );
  }

  Future<ApiResponse<T>> _handleConnectionError<T>(
    String endpoint,
    T Function(Map<String, dynamic>) parser,
  ) async {
    if (kDebugMode) {
      print('🌐 Connection error for: $endpoint');
    }
    final cachedData = await _getCachedData(endpoint);
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
      error: const NoInternetException(),
    );
  }

  Future<ApiResponse<T>> _handleGeneralError<T>(
    dynamic error,
    String endpoint,
    T Function(Map<String, dynamic>) parser,
  ) async {
    if (kDebugMode) {
      print('❌ Error for $endpoint: $error');
    }
    final cachedData = await _getCachedData(endpoint);
    if (cachedData != null) {
      return ApiResponse(
        data: parser(cachedData),
        source: DataSource.cache,
        status: ApiStatus.success,
        message: 'Using cached data due to error',
      );
    }
    return ApiResponse(
      status: ApiStatus.error,
      error: error,
    );
  }

  bool _hasValidMemoryCache(String key) {
    if (!_memoryCache.containsKey(key) || !_cacheTimestamps.containsKey(key)) {
      return false;
    }
    final timestamp = _cacheTimestamps[key]!;
    return DateTime.now().difference(timestamp) < cacheDuration;
  }

  Future<Map<String, dynamic>?> _getCachedData(String key) async {
    try {
      // Check memory cache first
      if (_hasValidMemoryCache(key)) {
        return _memoryCache[key];
      }

      // Check disk cache
      final cacheKey = _generateCacheKey(key);
      final cachedJson = _prefs.getString(cacheKey);
      if (cachedJson != null) {
        final data = json.decode(cachedJson) as Map<String, dynamic>;
        // Update memory cache
        _memoryCache[key] = data;
        _cacheTimestamps[key] = DateTime.now();
        return data;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Cache retrieval error: $e');
      }
    }
    return null;
  }

  Future<void> _cacheData(String key, Map<String, dynamic> data) async {
    try {
      // Memory cache
      _memoryCache[key] = data;
      _cacheTimestamps[key] = DateTime.now();

      // Manage memory cache size
      if (_memoryCache.length > maxMemoryCacheItems) {
        _clearOldestMemoryCache();
      }

      // Disk cache
      final cacheKey = _generateCacheKey(key);
      final jsonString = json.encode(data);
      await _prefs.setString(cacheKey, jsonString);

      // Manage disk cache size
      await _manageDiskCacheSize();
    } catch (e) {
      if (kDebugMode) {
        print('Cache storage error: $e');
      }
    }
  }

  void _clearOldestMemoryCache() {
    if (_cacheTimestamps.isEmpty) return;

    final oldestKey = _cacheTimestamps.entries
        .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
        .key;

    _memoryCache.remove(oldestKey);
    _cacheTimestamps.remove(oldestKey);
  }

  Future<void> _manageDiskCacheSize() async {
    final keys =
        _prefs.getKeys().where((k) => k.startsWith('api_cache_')).toList();
    int totalSize = 0;

    // Calculate total cache size
    for (final key in keys) {
      totalSize += (_prefs.getString(key)?.length.toInt() ?? 0);
    }

    // Remove oldest entries if size exceeds limit
    if (totalSize > maxDiskCacheSize) {
      keys.sort((a, b) {
        final aTime = DateTime.fromMillisecondsSinceEpoch(
            _prefs.getInt('${a}_timestamp') ?? 0);
        final bTime = DateTime.fromMillisecondsSinceEpoch(
            _prefs.getInt('${b}_timestamp') ?? 0);
        return aTime.compareTo(bTime);
      });

      for (final key in keys) {
        if (totalSize <= maxDiskCacheSize) break;
        final size = _prefs.getString(key)?.length ?? 0;
        _prefs.remove(key);
        _prefs.remove('${key}_timestamp');
        totalSize -= size;
      }
    }
  }

  String _generateCacheKey(String endpoint) {
    return 'api_cache_${endpoint.hashCode}';
  }

  Future<void> _cleanOldCache() async {
    final now = DateTime.now();

    // Clean memory cache
    _cacheTimestamps.removeWhere(
        (key, timestamp) => now.difference(timestamp) > cacheDuration);
    _memoryCache.removeWhere((key, _) => !_cacheTimestamps.containsKey(key));

    // Clean disk cache
    final keys = _prefs.getKeys().where((k) => k.startsWith('api_cache_'));
    for (final key in keys) {
      final timestamp = _prefs.getInt('${key}_timestamp');
      if (timestamp != null &&
          now.difference(DateTime.fromMillisecondsSinceEpoch(timestamp)) >
              cacheDuration) {
        _prefs.remove(key);
        _prefs.remove('${key}_timestamp');
      }
    }
  }

  // Public methods for cache management
  Future<void> clearCache(String endpoint) async {
    final cacheKey = _generateCacheKey(endpoint);
    _memoryCache.remove(endpoint);
    _cacheTimestamps.remove(endpoint);
    await _prefs.remove(cacheKey);
    await _prefs.remove('${cacheKey}_timestamp');
  }

  Future<void> clearAllCache() async {
    _memoryCache.clear();
    _cacheTimestamps.clear();

    final keys = _prefs.getKeys().where((k) => k.startsWith('api_cache_'));
    for (final key in keys) {
      await _prefs.remove(key);
      await _prefs.remove('${key}_timestamp');
    }
  }

  void dispose() {
    _client.close();
  }
}

// Response model for better type safety and error handling
class ApiResponse<T> {
  final T? data;
  final DataSource? source;
  final ApiStatus status;
  final dynamic error;
  final String? message;

  ApiResponse({
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

enum ApiStatus { success, error }

enum DataSource { network, cache, memoryCache }

class NoInternetException implements Exception {
  const NoInternetException();
  @override
  String toString() => 'No internet connection';
}
