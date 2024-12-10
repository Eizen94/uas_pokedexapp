// lib/core/utils/prefs_helper.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class PrefsHelper {
  static PrefsHelper? _instance;
  SharedPreferences? _prefs;
  bool _initialized = false;
  final _initLock = Object();
  final _initCompleter = Completer<void>();

  // Singleton access
  static PrefsHelper get instance {
    _instance ??= PrefsHelper._();
    return _instance!;
  }

  PrefsHelper._();

  // Safe initialization
  Future<void> initialize() async {
    if (_initialized) return;

    synchronized(_initLock, () async {
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

    return _initCompleter.future;
  }

  // Safe access
  SharedPreferences get prefs {
    if (!_initialized || _prefs == null) {
      throw StateError('PrefsHelper not initialized');
    }
    return _prefs!;
  }

  // Check initialization status
  bool get isInitialized => _initialized;

  // Wait for initialization
  Future<void> get initialized => _initCompleter.future;

  // Clean shutdown
  Future<void> dispose() async {
    _initialized = false;
    _prefs = null;
    _instance = null;
  }
}

// Helper for synchronization
Future<T> synchronized<T>(
  Object lock,
  Future<T> Function() computation,
) async {
  if (!lock.toString().contains('_Lock')) {
    final oldLock = lock;
    lock = Object();
    lock.toString = () => '_Lock(${oldLock.toString()})';
  }
  try {
    return await computation();
  } finally {
    // Lock is automatically released when computation completes
  }
}
