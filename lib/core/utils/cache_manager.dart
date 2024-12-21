// lib/core/utils/cache_manager.dart

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

/// Cache entry with metadata and type safety
class CacheEntry<T> {
  /// Unique key for cache entry
  final String key;

  /// Cached data with type safety
  final T data;

  /// Size in bytes
  final int size;

  /// Timestamp for expiry check
  final DateTime timestamp;

  /// Constructor
  const CacheEntry({
    required this.key,
    required this.data,
    required this.size,
    required this.timestamp,
  });

  /// Convert to JSON with type information
  Map<String, dynamic> toJson() => {
        'key': key,
        'data': data,
        'size': size,
        'timestamp': timestamp.toIso8601String(),
        'type': T.toString(),
      };

  /// Create from JSON with type checking
  static CacheEntry<T> fromJson<T>(Map<String, dynamic> json) {
    if (json['type'] != T.toString()) {
      throw StateError('Type mismatch in cache entry');
    }

    return CacheEntry<T>(
      key: json['key'] as String,
      data: json['data'] as T,
      size: json['size'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Cache manager implementing LRU strategy with proper type safety
class CacheManager {
  // Constants
  static const int _maxCacheSize = 5 * 1024 * 1024; // 5MB
  static const Duration _defaultExpiry = Duration(hours: 24);
  static const String _cacheKey = 'app_cache_data';

  // Singleton implementation with proper synchronization
  static final Lock _instanceLock = Lock();
  static CacheManager? _instance;
  static bool _initializing = false;

  // Internal state
  final Map<String, CacheEntry> _cache = <String, CacheEntry>{};
  late final SharedPreferences _prefs;
  bool _isInitialized = false;
  bool _isDisposed = false;
  int _currentSize = 0;

  // Private constructor
  CacheManager._();

  /// Get cache manager instance with proper initialization
  static Future<CacheManager> initialize() async {
    if (_instance != null &&
        _instance!._isInitialized &&
        !_instance!._isDisposed) {
      return _instance!;
    }

    return await _instanceLock.synchronized(() async {
      if (_initializing) {
        while (_initializing) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (_instance != null && _instance!._isInitialized) {
          return _instance!;
        }
      }

      _initializing = true;

      try {
        debugPrint('📦 CacheManager: Starting initialization...');

        final instance = CacheManager._();
        await instance._initialize();

        _instance = instance;
        _initializing = false;

        debugPrint('✅ CacheManager: Initialization complete');
        return instance;
      } catch (e, stack) {
        _initializing = false;
        debugPrint('❌ CacheManager: Initialization failed: $e');
        debugPrint(stack.toString());
        rethrow;
      }
    });
  }

  /// Initialize cache manager
  Future<void> _initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadCache();
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ CacheManager: Initialization error: $e');
      rethrow;
    }
  }

  /// Get cached value with type safety
  Future<T?> get<T>(String key) async {
    _verifyState();

    try {
      final entry = _cache[key];
      if (entry == null) return null;

      if (DateTime.now().difference(entry.timestamp) > _defaultExpiry) {
        await remove(key);
        return null;
      }

      if (entry.data is! T) {
        throw StateError('Type mismatch in cache');
      }

      return entry.data as T;
    } catch (e) {
      debugPrint('❌ CacheManager: Error getting from cache: $e');
      return null;
    }
  }

  /// Put value in cache with type checking
  Future<void> put<T>(String key, T value) async {
    _verifyState();

    try {
      final String serialized = json.encode(value);
      final int size = utf8.encode(serialized).length;

      if (size > _maxCacheSize) {
        throw const StateError('Value too large for cache');
      }

      if (_cache.containsKey(key)) {
        await remove(key);
      }

      // Enforce size limit with LRU eviction
      while (_currentSize + size > _maxCacheSize && _cache.isNotEmpty) {
        final String oldestKey = _cache.keys.first;
        await remove(oldestKey);
      }

      final entry = CacheEntry<T>(
        key: key,
        data: value,
        size: size,
        timestamp: DateTime.now(),
      );

      _cache[key] = entry;
      _currentSize += size;

      await _persistCache();
    } catch (e) {
      debugPrint('❌ CacheManager: Error putting to cache: $e');
      rethrow;
    }
  }

  /// Remove item from cache
  Future<void> remove(String key) async {
    _verifyState();

    final entry = _cache.remove(key);
    if (entry != null) {
      _currentSize -= entry.size;
      await _persistCache();
    }
  }

  /// Clear all cache data
  Future<void> clear() async {
    _verifyState();

    _cache.clear();
    _currentSize = 0;
    await _persistCache();
  }

  /// Load cache from persistent storage
  Future<void> _loadCache() async {
    try {
      final String? data = _prefs.getString(_cacheKey);
      if (data == null) return;

      final List<dynamic> cacheData = json.decode(data) as List<dynamic>;

      _cache.clear();
      _currentSize = 0;

      for (final item in cacheData) {
        final entry = CacheEntry.fromJson(item as Map<String, dynamic>);
        _cache[entry.key] = entry;
        _currentSize += entry.size;
      }
    } catch (e) {
      debugPrint('❌ CacheManager: Error loading cache: $e');
      _cache.clear();
      _currentSize = 0;
    }
  }

  /// Persist cache to storage
  Future<void> _persistCache() async {
    try {
      final cacheData = _cache.values.map((e) => e.toJson()).toList();
      final String serialized = json.encode(cacheData);
      await _prefs.setString(_cacheKey, serialized);
    } catch (e) {
      debugPrint('❌ CacheManager: Error persisting cache: $e');
    }
  }

  /// Verify manager state
  void _verifyState() {
    if (_isDisposed) {
      throw StateError('CacheManager has been disposed');
    }
    if (!_isInitialized) {
      throw StateError('CacheManager not initialized');
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    await clear();
    _isDisposed = true;
    _isInitialized = false;
  }

  /// Get current cache size
  int get currentSize => _currentSize;

  /// Get maximum cache size
  int get maxSize => _maxCacheSize;

  /// Check if cache is initialized
  bool get isInitialized => _isInitialized;

  /// Check if cache is disposed
  bool get isDisposed => _isDisposed;
}
