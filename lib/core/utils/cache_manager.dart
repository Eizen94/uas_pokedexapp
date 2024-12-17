// lib/core/utils/cache_manager.dart

/// Cache management utility for efficient data storage and retrieval.
/// Implements LRU (Least Recently Used) caching with a strict 5MB size limit.
library;

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

  /// Convert entry to JSON
  Map<String, dynamic> toJson() => {
        'key': key,
        'data': data,
        'size': size,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Create entry from JSON
  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
        key: json['key'] as String,
        data: json['data'],
        size: json['size'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Cache manager implementing LRU strategy with size limits
class CacheManager {
  static const int _maxCacheSize = 5 * 1024 * 1024; // 5MB in bytes
  static const Duration _defaultExpiry = Duration(hours: 24);

  final Lock _lock = Lock();
  final LinkedHashMap<String, CacheEntry> _cache = LinkedHashMap();
  final SharedPreferences _prefs;
  int _currentSize = 0;

  CacheManager._(this._prefs) {
    _loadPersistedCache();
  }

  /// Initialize cache manager
  static Future<CacheManager> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    return CacheManager._(prefs);
  }

  /// Get cached data
  Future<T?> get<T>(String key) async {
    return await _lock.synchronized(() {
      final entry = _cache[key];
      if (entry == null) return null;

      // Check expiry
      if (DateTime.now().difference(entry.timestamp) > _defaultExpiry) {
        _remove(key);
        return null;
      }

      // Move to front (most recently used)
      _cache.remove(key);
      _cache[key] = entry;

      return entry.data as T?;
    });
  }

  /// Put data in cache
  Future<void> put<T>(String key, T data) async {
    await _lock.synchronized(() {
      final String serialized = json.encode(data);
      final int size = utf8.encode(serialized).length;

      // Don't cache if single item exceeds max size
      if (size > _maxCacheSize) return;

      // Remove existing entry if present
      if (_cache.containsKey(key)) {
        _remove(key);
      }

      // Make space if needed
      while (_currentSize + size > _maxCacheSize && _cache.isNotEmpty) {
        _remove(_cache.keys.first); // Remove oldest
      }

      // Add new entry
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

  /// Remove item from cache
  void _remove(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _currentSize -= entry.size;
      _persistCache();
    }
  }

  /// Clear entire cache
  Future<void> clear() async {
    await _lock.synchronized(() {
      _cache.clear();
      _currentSize = 0;
      _persistCache();
    });
  }

  /// Persist cache to storage
  Future<void> _persistCache() async {
    final serialized =
        json.encode(_cache.values.map((e) => e.toJson()).toList());
    await _prefs.setString('cache_data', serialized);
  }

  /// Load persisted cache
  Future<void> _loadPersistedCache() async {
    await _lock.synchronized(() {
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
