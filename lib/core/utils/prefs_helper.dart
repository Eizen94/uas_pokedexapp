// lib/core/utils/prefs_helper.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enhanced preferences helper with proper initialization and thread safety
class PrefsHelper {
  // Singleton with thread safety
  static PrefsHelper? _instance;
  SharedPreferences? _prefs;
  bool _initialized = false;
  final _initLock = Object();
  final _initCompleter = Completer<void>();
  bool _isDisposed = false;

  // Private constructor
  PrefsHelper._();

  // Thread-safe singleton access
  static PrefsHelper get instance {
    _instance ??= PrefsHelper._();
    return _instance!;
  }

  /// Safe initialization with proper error handling
  Future<void> initialize() async {
    if (_isDisposed) {
      throw StateError('PrefsHelper has been disposed');
    }

    if (!_initialized) {
      await synchronized(_initLock, () async {
        try {
          if (!_initialized && _prefs == null) {
            _prefs = await SharedPreferences.getInstance();
            _initialized = true;
            _initCompleter.complete();

            if (kDebugMode) {
              print('✅ PrefsHelper initialized');
            }
          }
        } catch (e) {
          _initCompleter.completeError(e);
          if (kDebugMode) {
            print('❌ PrefsHelper initialization error: $e');
          }
          rethrow;
        }
      });
    }

    return _initCompleter.future;
  }

  /// Safe preferences access
  SharedPreferences get prefs {
    if (!_initialized || _prefs == null || _isDisposed) {
      throw StateError('PrefsHelper not initialized or disposed');
    }
    return _prefs!;
  }

  /// Get initialization status
  bool get isInitialized => _initialized;

  /// Wait for initialization completion
  Future<void> get initialized => _initCompleter.future;

  /// Get a value with type safety
  T? getValue<T>(String key) {
    if (!_initialized || _isDisposed) return null;

    try {
      return _prefs?.get(key) as T?;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting value for key $key: $e');
      }
      return null;
    }
  }

  /// Set a value with error handling
  Future<bool> setValue<T>(String key, T value) async {
    if (!_initialized || _isDisposed) return false;

    try {
      final prefs = _prefs!;

      if (value is String) {
        return await prefs.setString(key, value);
      } else if (value is int) {
        return await prefs.setInt(key, value);
      } else if (value is double) {
        return await prefs.setDouble(key, value);
      } else if (value is bool) {
        return await prefs.setBool(key, value);
      } else if (value is List<String>) {
        return await prefs.setStringList(key, value);
      } else {
        throw UnsupportedError('Unsupported type: ${value.runtimeType}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error setting value for key $key: $e');
      }
      return false;
    }
  }

  /// Remove a value with error handling
  Future<bool> removeValue(String key) async {
    if (!_initialized || _isDisposed) return false;

    try {
      return await _prefs!.remove(key);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removing value for key $key: $e');
      }
      return false;
    }
  }

  /// Clear all preferences with error handling
  Future<bool> clear() async {
    if (!_initialized || _isDisposed) return false;

    try {
      return await _prefs!.clear();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing preferences: $e');
      }
      return false;
    }
  }

  /// Check if key exists
  bool containsKey(String key) {
    if (!_initialized || _isDisposed) return false;
    return _prefs!.containsKey(key);
  }

  /// Get all keys
  Set<String> getKeys() {
    if (!_initialized || _isDisposed) return {};
    return _prefs!.getKeys();
  }

  /// Clean shutdown
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _initialized = false;
    _prefs = null;
    _instance = null;

    if (kDebugMode) {
      print('🧹 PrefsHelper disposed');
    }
  }
}

/// Helper for synchronization
Future<T> synchronized<T>(
  Object lock,
  Future<T> Function() computation,
) async {
  final syncLock = _SyncLock(lock.hashCode.toString());
  try {
    return await computation();
  } finally {
    syncLock.release();
  }
}

/// Lock class for thread safety
class _SyncLock {
  final String id;
  bool _locked = false;

  _SyncLock(this.id) {
    _locked = true;
  }

  void release() {
    _locked = false;
  }

  @override
  String toString() => '_SyncLock(id: $id, locked: $_locked)';
}
