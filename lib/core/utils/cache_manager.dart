// lib/core/utils/cache_manager.dart

import 'dart:collection';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

/// Cache entry with metadata
class CacheEntry {
  final String key;
  final dynamic data;
  final int size;
  final DateTime timestamp;

  const CacheEntry({
    required this.key,
    required this.data,
    required this.size,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'data': data,
        'size': size,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
        key: json['key'] as String,
        data: json['data'],
        size: json['size'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Cache manager implementing LRU strategy with size limits
class CacheManager {
  static CacheManager? _instance;
  static final _initLock = Lock();
  static bool _initializing = false;

  // Constants
  static const int maxCacheSize = 5 * 1024 * 1024; // 5MB
  static const Duration defaultExpiry = Duration(hours: 24);

  final LinkedHashMap<String, CacheEntry> _cache = LinkedHashMap();
  late final SharedPreferences _prefs;
  int _currentSize = 0;
  bool _isInitialized = false;

  CacheManager._internal();

  static Future<CacheManager> initialize() async {
    if (_initializing) {
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_instance != null) {
        return _instance!;
      }
    }

    if (_instance != null && _instance!._isInitialized) {
      debugPrint('📦 CacheManager: Returning existing initialized instance');
      return _instance!;
    }

    _initializing = true;

    return await _initLock.synchronized(() async {
      try {
        debugPrint('📦 CacheManager: Starting initialization...');

        if (_instance == null) {
          debugPrint('📦 CacheManager: Creating new instance...');
          _instance = CacheManager._internal();
        }

        final prefs = await SharedPreferences.getInstance().timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException(
              'Failed to get SharedPreferences instance'),
        );

        _instance!._prefs = prefs;

        debugPrint('📦 CacheManager: Loading persisted cache...');
        await _instance!._loadPersistedCache().timeout(
          const Duration(seconds: 15),
          onTimeout: () => debugPrint(
              '📦 CacheManager: Cache load timeout, continuing with empty cache'),
        );

        _instance!._isInitialized = true;
        _initializing = false;

        debugPrint('✅ CacheManager: Initialization complete');
        debugPrint('📊 CacheManager Stats:');
        debugPrint('- Current Size: ${_instance!._currentSize} bytes');
        debugPrint('- Max Size: $maxCacheSize bytes');
        debugPrint('- Items in cache: ${_instance!._cache.length}');

        return _instance!;

      } catch (e, stack) {
        _initializing = false;
        debugPrint('❌ CacheManager: Initialization failed');
        debugPrint('Error: $e');
        debugPrint('Stack trace: $stack');

        if (_instance == null || !_instance!._isInitialized) {
          debugPrint(
              '📦 CacheManager: Creating fallback instance with empty cache...');
          _instance = CacheManager._internal();
          _instance!._prefs = await SharedPreferences.getInstance();
          _instance!._isInitialized = true;
        }

        return _instance!;
      }
    });
  }

  // Getter for cache size limits
  int get currentSize => _currentSize;
  int get maxSize => maxCacheSize;

  /// Get cached data
  Future<T?> get<T>(String key) async {
    _verifyInitialized();

    debugPrint('📦 CacheManager: Getting data for key: $key');

    final entry = _cache[key];
    if (entry == null) {
      debugPrint('📦 CacheManager: Cache miss for key: $key');
      return null;
    }

    if (DateTime.now().difference(entry.timestamp) > _defaultExpiry) {
      debugPrint('📦 CacheManager: Expired data for key: $key');
      _remove(key);
      return null;
    }

    debugPrint('📦 CacheManager: Cache hit for key: $key');
    _cache.remove(key);
    _cache[key] = entry;
    return entry.data as T?;
  }

  /// Put data in cache
  Future<void> put<T>(String key, T data) async {
    _verifyInitialized();

    debugPrint('📦 CacheManager: Putting data for key: $key');

    try {
      final String serialized = json.encode(data);
      final int size = utf8.encode(serialized).length;

      if (size > _maxCacheSize) {
        debugPrint('❌ CacheManager: Data too large for cache');
        return;
      }

      if (_cache.containsKey(key)) {
        debugPrint('📦 CacheManager: Removing existing data for key: $key');
        _remove(key);
      }

      while (_currentSize + size > _maxCacheSize && _cache.isNotEmpty) {
        debugPrint('📦 CacheManager: Evicting old cache entries');
        _remove(_cache.keys.first);
      }

      final entry = CacheEntry(
        key: key,
        data: data,
        size: size,
        timestamp: DateTime.now(),
      );

      _cache[key] = entry;
      _currentSize += size;

      debugPrint('📦 CacheManager: Successfully cached data');
      debugPrint('- Key: $key');
      debugPrint('- Size: $size bytes');
      debugPrint('- Total Cache Size: $_currentSize bytes');

      _persistCache();
    } catch (e, stack) {
      debugPrint('❌ CacheManager: Failed to cache data');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  void _remove(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _currentSize -= entry.size;
      debugPrint(
          '📦 CacheManager: Removed entry - Key: $key, Size: ${entry.size} bytes');
      _persistCache();
    }
  }

  /// Clear all cached data
  Future<void> clear() async {
    _verifyInitialized();
    debugPrint('📦 CacheManager: Clearing all cache data');
    _cache.clear();
    _currentSize = 0;
    _persistCache();
  }

  Future<void> _persistCache() async {
    try {
      debugPrint('📦 CacheManager: Persisting cache to storage...');
      final serialized =
          json.encode(_cache.values.map((e) => e.toJson()).toList());
      await _prefs.setString('cache_data', serialized);
      debugPrint('✅ CacheManager: Cache persisted successfully');
    } catch (e, stack) {
      debugPrint('❌ CacheManager: Failed to persist cache');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  Future<void> _loadPersistedCache() async {
    try {
      debugPrint('📦 CacheManager: Starting to load persisted cache...');

      debugPrint('📦 CacheManager: Getting string from SharedPreferences...');
      final String? serialized = _prefs.getString('cache_data');

      if (serialized != null) {
        debugPrint('📦 CacheManager: Found persisted data, decoding JSON...');
        final List<dynamic> data = json.decode(serialized);
        debugPrint('📦 CacheManager: JSON decoded successfully');

        _cache.clear();
        _currentSize = 0;

        debugPrint('📦 CacheManager: Processing ${data.length} entries...');
        var processedCount = 0;
        for (final item in data) {
          debugPrint(
              '📦 CacheManager: Processing entry ${++processedCount}/${data.length}');
          final entry = CacheEntry.fromJson(item as Map<String, dynamic>);
          _cache[entry.key] = entry;
          _currentSize += entry.size;
          debugPrint('📦 CacheManager: Entry processed successfully');
        }

        debugPrint('✅ CacheManager: All entries processed');
      } else {
        debugPrint('📦 CacheManager: No persisted cache found, starting fresh');
      }

      debugPrint('✅ CacheManager: Load complete');
    } catch (e, stack) {
      debugPrint('❌ CacheManager: Error loading persisted cache: $e');
      debugPrint(stack.toString());
      // Continue with empty cache
      _cache.clear();
      _currentSize = 0;
    }
  }

  /// Verify manager is initialized
  void _verifyInitialized() {
    if (!_isInitialized) {
      debugPrint('❌ CacheManager: Attempting to use uninitialized instance');
      throw StateError('CacheManager must be initialized before use');
    }
  }

  /// Get current cache size in bytes
  int get currentSize => _currentSize;

  /// Get maximum cache size in bytes
  int get maxSize => _maxCacheSize;
}
