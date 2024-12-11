// lib/core/config/firebase_config.dart

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/prefs_helper.dart';
import '../constants/api_paths.dart';

/// Enhanced Firebase configuration with proper initialization, monitoring and cleanup
class FirebaseConfig {
  // Singleton instance with proper initialization check
  static FirebaseConfig? _instance;
  static final Object _instanceLock = Object();

  // Core Firebase instances
  final FirebaseApp _app;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // Status monitoring
  final StreamController<bool> _authStatusController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _firestoreStatusController =
      StreamController<bool>.broadcast();
  final StreamController<FirebaseStatus> _statusController =
      StreamController<FirebaseStatus>.broadcast();

  // State management
  bool _initialized = false;
  bool _initializing = false;
  bool _disposed = false;
  final Completer<void> _initCompleter = Completer<void>();
  Timer? _healthCheckTimer;
  DateTime? _lastHealthCheck;

  // Constants
  static const Duration _healthCheckInterval = Duration(minutes: 5);
  static const Duration _initTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Private constructor
  FirebaseConfig._(this._app, this._auth, this._firestore);

  /// Get singleton instance with initialization check
  static Future<FirebaseConfig> getInstance() async {
    if (_instance != null) return _instance!;

    synchronized(_instanceLock, () async {
      if (_instance != null) return _instance!;

      try {
        final app = await Firebase.initializeApp();
        final auth = FirebaseAuth.instance;
        final firestore = FirebaseFirestore.instance;

        _instance = FirebaseConfig._(app, auth, firestore);
        await _instance!._initialize();

        return _instance!;
      } catch (e) {
        throw FirebaseConfigException('Failed to initialize Firebase: $e');
      }
    });

    return _instance!;
  }

  /// Initialize Firebase with proper error handling and retry mechanism
  Future<void> _initialize() async {
    if (_initialized || _disposed) return;
    if (_initializing) return _initCompleter.future;

    _initializing = true;
    int retryCount = 0;

    try {
      while (retryCount < _maxRetries) {
        try {
          // Configure Auth persistence
          await _auth.setPersistence(Persistence.LOCAL);

          // Configure Firestore settings
          _firestore.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );

          // Initialize health monitoring
          _startHealthCheck();

          _initialized = true;
          _initCompleter.complete();

          _updateStatus(FirebaseStatus.ready);

          if (kDebugMode) {
            print('✅ Firebase initialized successfully');
          }
          return;
        } catch (e) {
          retryCount++;
          if (kDebugMode) {
            print('⚠️ Firebase initialization attempt $retryCount failed: $e');
          }

          if (retryCount == _maxRetries) {
            throw FirebaseConfigException(
              'Failed to initialize Firebase after $retryCount attempts: $e',
            );
          }

          await Future.delayed(_retryDelay * retryCount);
        }
      }
    } catch (e) {
      _initCompleter.completeError(e);
      _updateStatus(FirebaseStatus.error, error: e);
      rethrow;
    } finally {
      _initializing = false;
    }
  }

  /// Start periodic health checks
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      _performHealthCheck();
    });
  }

  /// Perform Firebase services health check
  Future<void> _performHealthCheck() async {
    try {
      // Check Auth
      final authOk = _auth.currentUser != null || await _checkAuthHealth();
      _authStatusController.add(authOk);

      // Check Firestore
      final firestoreOk = await _checkFirestoreHealth();
      _firestoreStatusController.add(firestoreOk);

      _lastHealthCheck = DateTime.now();
      _updateStatus(authOk && firestoreOk
          ? FirebaseStatus.ready
          : FirebaseStatus.degraded);
    } catch (e) {
      _updateStatus(FirebaseStatus.error, error: e);
      if (kDebugMode) {
        print('❌ Firebase health check failed: $e');
      }
    }
  }

  /// Check Auth service health
  Future<bool> _checkAuthHealth() async {
    try {
      await _auth.signInAnonymously();
      await _auth.signOut();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check Firestore service health
  Future<bool> _checkFirestoreHealth() async {
    try {
      final testDoc = _firestore.collection('health_check').doc();
      await testDoc.set({'timestamp': FieldValue.serverTimestamp()});
      await testDoc.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update Firebase status
  void _updateStatus(FirebaseStatus status, {Object? error}) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }

    if (error != null && kDebugMode) {
      print('Firebase Status Update: ${status.name} (Error: $error)');
    }
  }

  /// Get current Firebase status
  Stream<FirebaseStatus> get status => _statusController.stream;

  /// Get Auth status stream
  Stream<bool> get authStatus => _authStatusController.stream;

  /// Get Firestore status stream
  Stream<bool> get firestoreStatus => _firestoreStatusController.stream;

  /// Get initialization status
  bool get isInitialized => _initialized;

  /// Get Firebase Auth instance
  FirebaseAuth get auth {
    _throwIfNotInitialized();
    return _auth;
  }

  /// Get Firestore instance
  FirebaseFirestore get firestore {
    _throwIfNotInitialized();
    return _firestore;
  }

  /// Reset Firebase configuration
  Future<void> reset() async {
    if (_disposed) return;

    try {
      // Sign out user
      await _auth.signOut();

      // Clear Firestore cache
      await _firestore.terminate();
      await _firestore.clearPersistence();

      // Clear local storage
      final prefs = await PrefsHelper.instance.prefs;
      await prefs.clear();

      _updateStatus(FirebaseStatus.resetting);

      // Re-initialize
      await _initialize();
    } catch (e) {
      _updateStatus(FirebaseStatus.error, error: e);
      rethrow;
    }
  }

  /// Clean resource disposal
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;
    _healthCheckTimer?.cancel();

    await Future.wait([
      _authStatusController.close(),
      _firestoreStatusController.close(),
      _statusController.close(),
    ]);

    _initialized = false;
    _instance = null;

    if (kDebugMode) {
      print('🧹 FirebaseConfig disposed');
    }
  }

  /// Check initialization status
  void _throwIfNotInitialized() {
    if (!_initialized) {
      throw FirebaseConfigException('FirebaseConfig not initialized');
    }
    if (_disposed) {
      throw FirebaseConfigException('FirebaseConfig has been disposed');
    }
  }
}

/// Firebase status enum
enum FirebaseStatus {
  initializing('Initializing'),
  ready('Ready'),
  degraded('Degraded Performance'),
  error('Error'),
  resetting('Resetting');

  final String name;
  const FirebaseStatus(this.name);
}

/// Firebase configuration exception
class FirebaseConfigException implements Exception {
  final String message;

  FirebaseConfigException(this.message);

  @override
  String toString() => 'FirebaseConfigException: $message';
}

/// Thread-safe operation helper
Future<T> synchronized<T>(
  Object lock,
  Future<T> Function() computation,
) async {
  if (_locks.containsKey(lock)) {
    await _locks[lock]!.future;
  }

  final completer = Completer<void>();
  _locks[lock] = completer;

  try {
    return await computation();
  } finally {
    _locks.remove(lock);
    completer.complete();
  }
}

// Global locks registry
final Map<Object, Completer<void>> _locks = {};
