// lib/core/utils/cache_manager.dart

import 'dart:collection';
import 'dart:convert';
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

  static const int _maxCacheSize = 5 * 1024 * 1024; // 5MB
  static const Duration _defaultExpiry = Duration(hours: 24);

  final LinkedHashMap<String, CacheEntry> _cache = LinkedHashMap();
  final SharedPreferences _prefs;
  int _currentSize = 0;
  bool _isInitialized = false;

  CacheManager._(this._prefs);

  /// Initialize cache manager as singleton
  static Future<CacheManager> initialize() async {
    if (_instance != null) {
      return _instance!;
    }

    return await _initLock.synchronized(() async {
      if (_instance != null) {
        return _instance!;
      }

      final prefs = await SharedPreferences.getInstance();
      _instance = CacheManager._(prefs);
      await _instance!._loadPersistedCache();
      _instance!._isInitialized = true;
      return _instance!;
    });
  }

  /// Get cached data
  Future<T?> get<T>(String key) async {
    return await _initLock.synchronized(() {
      final entry = _cache[key];
      if (entry == null) return null;

      if (DateTime.now().difference(entry.timestamp) > _defaultExpiry) {
        _remove(key);
        return null;
      }

      _cache.remove(key);
      _cache[key] = entry;
      return entry.data as T?;
    });
  }

  /// Put data in cache
  Future<void> put<T>(String key, T data) async {
    await _initLock.synchronized(() {
      final String serialized = json.encode(data);
      final int size = utf8.encode(serialized).length;

      if (size > _maxCacheSize) return;

      if (_cache.containsKey(key)) {
        _remove(key);
      }

      while (_currentSize + size > _maxCacheSize && _cache.isNotEmpty) {
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
      _persistCache();
    });
  }

  void _remove(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _currentSize -= entry.size;
      _persistCache();
    }
  }

  Future<void> clear() async {
    await _initLock.synchronized(() {
      _cache.clear();
      _currentSize = 0;
      _persistCache();
    });
  }

  Future<void> _persistCache() async {
    final serialized =
        json.encode(_cache.values.map((e) => e.toJson()).toList());
    await _prefs.setString('cache_data', serialized);
  }

  Future<void> _loadPersistedCache() async {
    await _initLock.synchronized(() {
      final String? serialized = _prefs.getString('cache_data');
      if (serialized != null) {
        final List<dynamic> data = json.decode(serialized);
        for (final item in data) {
          final entry = CacheEntry.fromJson(item as Map<String, dynamic>);
          _cache[entry.key] = entry;
          _currentSize += entry.size;
        }
      }
    });
  }

  /// Get current cache size in bytes
  int get currentSize => _currentSize;

  /// Get maximum cache size in bytes
  int get maxSize => _maxCacheSize;
}
