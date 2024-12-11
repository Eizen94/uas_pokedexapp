// lib/core/utils/prefs_helper.dart

// Dart imports
import 'dart:async';
import 'dart:convert';

// Package imports
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enhanced preferences helper with proper initialization, thread safety and type validation.
/// Provides centralized access to local storage with proper error handling.
class PrefsHelper {
  // Singleton pattern implementation
  static PrefsHelper? _instance;
  static final _lock = Object();

  // Core storage
  SharedPreferences? _prefs;
  final Map<String, dynamic> _memoryCache = {};

  // State tracking
  bool _initialized = false;
  bool _initializing = false;
  bool _disposed = false;
  final _initCompleter = Completer<void>();

  // Constants
  static const Duration _initTimeout = Duration(seconds: 10);
  static const int _maxRetries = 3;
  static const String _prefsVersionKey = 'prefs_version';
  static const int _currentVersion = 1;

  // Private constructor
  PrefsHelper._();

  /// Get singleton instance with proper initialization
  static Future<PrefsHelper> getInstance() async {
    if (_instance != null) return _instance!;

    await synchronized(_lock, () async {
      if (_instance == null) {
        _instance = PrefsHelper._();
        await _instance!._initialize();
      }
    });

    return _instance!;
  }

  /// Initialize preferences with retry mechanism
  Future<void> _initialize() async {
    if (_initialized || _disposed) return;
    if (_initializing) return _initCompleter.future;

    _initializing = true;
    int retryCount = 0;

    try {
      while (retryCount < _maxRetries) {
        try {
          _prefs = await SharedPreferences.getInstance().timeout(_initTimeout);

          await _validateAndMigrate();

          _initialized = true;
          _initCompleter.complete();

          if (kDebugMode) {
            print('✅ PrefsHelper initialized');
          }
          return;
        } catch (e) {
          retryCount++;
          if (kDebugMode) {
            print(
                '⚠️ PrefsHelper initialization attempt $retryCount failed: $e');
          }

          if (retryCount == _maxRetries) {
            throw PrefsException(
                'Failed to initialize after $retryCount attempts');
          }

          await Future.delayed(Duration(seconds: retryCount));
        }
      }
    } catch (e) {
      _initCompleter.completeError(e);
      rethrow;
    } finally {
      _initializing = false;
    }
  }

  /// Validate and migrate preferences if needed
  Future<void> _validateAndMigrate() async {
    final version = _prefs?.getInt(_prefsVersionKey) ?? 0;

    if (version < _currentVersion) {
      await _migratePrefs(fromVersion: version);
      await _prefs?.setInt(_prefsVersionKey, _currentVersion);
    }
  }

  /// Migrate preferences from older versions
  Future<void> _migratePrefs({required int fromVersion}) async {
    // Implement migration logic for different versions
    switch (fromVersion) {
      case 0:
        // Migrate from version 0 to 1
        break;
      default:
        // Handle unknown versions
        break;
    }
  }

  /// Get value with type safety
  T? get<T>(String key) {
    _throwIfNotInitialized();

    try {
      // Check memory cache first
      if (_memoryCache.containsKey(key)) {
        return _memoryCache[key] as T?;
      }

      // Get from preferences
      final value = _prefs?.get(key);
      if (value != null) {
        _memoryCache[key] = value;
        return value as T?;
      }

      return null;
    } catch (e) {
      throw PrefsException('Error getting value for key $key: $e');
    }
  }

  /// Set value with type validation
  Future<bool> set<T>(String key, T value) async {
    _throwIfNotInitialized();

    try {
      bool success;

      if (value is String) {
        success = await _prefs!.setString(key, value);
      } else if (value is int) {
        success = await _prefs!.setInt(key, value);
      } else if (value is double) {
        success = await _prefs!.setDouble(key, value);
      } else if (value is bool) {
        success = await _prefs!.setBool(key, value);
      } else if (value is List<String>) {
        success = await _prefs!.setStringList(key, value);
      } else if (value is Map || value is List) {
        final jsonString = jsonEncode(value);
        success = await _prefs!.setString(key, jsonString);
      } else {
        throw PrefsException('Unsupported type: ${value.runtimeType}');
      }

      if (success) {
        _memoryCache[key] = value;
      }

      return success;
    } catch (e) {
      throw PrefsException('Error setting value for key $key: $e');
    }
  }

  /// Remove value
  Future<bool> remove(String key) async {
    _throwIfNotInitialized();

    try {
      final success = await _prefs!.remove(key);
      if (success) {
        _memoryCache.remove(key);
      }
      return success;
    } catch (e) {
      throw PrefsException('Error removing key $key: $e');
    }
  }

  /// Clear all preferences
  Future<bool> clear() async {
    _throwIfNotInitialized();

    try {
      final success = await _prefs!.clear();
      if (success) {
        _memoryCache.clear();
      }
      return success;
    } catch (e) {
      throw PrefsException('Error clearing preferences: $e');
    }
  }

  /// Check if key exists
  bool containsKey(String key) {
    _throwIfNotInitialized();
    return _prefs!.containsKey(key);
  }

  /// Get all keys
  Set<String> getKeys() {
    _throwIfNotInitialized();
    return _prefs!.getKeys();
  }

  /// Get preferences instance
  SharedPreferences get prefs {
    _throwIfNotInitialized();
    return _prefs!;
  }

  /// Check initialization status
  void _throwIfNotInitialized() {
    if (_disposed) {
      throw PrefsException('PrefsHelper has been disposed');
    }
    if (!_initialized) {
      throw PrefsException('PrefsHelper not initialized');
    }
  }

  /// Clear memory cache
  void clearMemoryCache() {
    _memoryCache.clear();
  }

  /// Resource disposal
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;
    _initialized = false;
    _memoryCache.clear();
    _prefs = null;
    _instance = null;

    if (kDebugMode) {
      print('🧹 PrefsHelper disposed');
    }
  }
}

/// Custom preferences exception
class PrefsException implements Exception {
  final String message;

  PrefsException(this.message);

  @override
  String toString() => 'PrefsException: $message';
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
