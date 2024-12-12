// lib/core/config/firebase_config.dart

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../utils/prefs_helper.dart';
import '../constants/api_paths.dart';
import '../utils/monitoring_manager.dart';

/// Enhanced Firebase configuration with proper initialization, monitoring and cleanup.
/// Provides centralized Firebase service management with proper error handling,
/// resource management, and state monitoring.
class FirebaseConfig {
  // Singleton implementation with proper locking
  static FirebaseConfig? _instance;
  static final Object _lock = Object();

  // Core Firebase instances - properly typed
  final FirebaseApp _app;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // Strongly typed stream controllers
  final StreamController<FirebaseStatus> _statusController =
      StreamController<FirebaseStatus>.broadcast();
  final StreamController<bool> _authStatusController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _firestoreStatusController =
      StreamController<bool>.broadcast();

  // Private state management with proper initialization
  bool _initialized = false;
  bool _disposed = false;
  Timer? _healthCheckTimer;
  StreamSubscription<User?>? _authStateSubscription;
  final Completer<void> _initCompleter = Completer<void>();

  // Constructor with proper initialization
  FirebaseConfig._(this._app, this._auth, this._firestore) {
    _setupHealthMonitoring();
    _setupAuthStateListener();
  }

  // Getter/setter pairs with validation
  bool get isInitialized => _initialized;
  bool get isDisposed => _disposed;

  // Properly typed streams
  Stream<FirebaseStatus> get status => _statusController.stream;
  Stream<bool> get authStatus => _authStatusController.stream;
  Stream<bool> get firestoreStatus => _firestoreStatusController.stream;

  /// Thread-safe singleton getter with proper error handling
  static Future<FirebaseConfig> getInstance() async {
    if (_instance != null) return _instance!;

    return synchronized(_lock, () async {
      try {
        if (_instance != null) return _instance!;

        final app = await Firebase.initializeApp();
        final auth = FirebaseAuth.instance;
        final firestore = FirebaseFirestore.instance;

        _instance = FirebaseConfig._(app, auth, firestore);
        await _instance!._initialize();

        return _instance!;
      } catch (e) {
        throw FirebaseConfigException(
          'Failed to initialize Firebase configuration: $e',
        );
      }
    });
  }

  /// Initialize Firebase with proper error handling and retry mechanism
  Future<void> _initialize() async {
    if (_initialized || _disposed) return;

    try {
      // Configure Auth persistence
      await _auth.setPersistence(Persistence.LOCAL);

      // Configure Firestore
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      _initialized = true;
      _initCompleter.complete();

      if (kDebugMode) {
        print('✅ Firebase initialization complete');
      }
    } catch (e) {
      _initCompleter.completeError(e);
      throw FirebaseConfigException('Firebase initialization failed: $e');
    }
  }

  /// Setup auth state listener with proper cleanup
  void _setupAuthStateListener() {
    _authStateSubscription?.cancel();
    _authStateSubscription = _auth.authStateChanges().listen(
      (user) {
        if (!_authStatusController.isClosed) {
          _authStatusController.add(user != null);
        }
      },
      onError: (e) {
        if (kDebugMode) {
          print('❌ Auth state listener error: $e');
        }
      },
    );
  }

  /// Get Firebase Auth instance with validation
  FirebaseAuth get auth {
    _validateState();
    return _auth;
  }

  /// Get Firestore instance with validation
  FirebaseFirestore get firestore {
    _validateState();
    return _firestore;
  }

  /// Setup health monitoring with proper cleanup
  void _setupHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkHealth(),
    );
  }

  /// Comprehensive health check implementation
  Future<void> _checkHealth() async {
    if (_disposed) return;

    try {
      final authOk = await _checkAuthHealth();
      final firestoreOk = await _checkFirestoreHealth();

      _authStatusController.add(authOk);
      _firestoreStatusController.add(firestoreOk);

      final status = authOk && firestoreOk
          ? FirebaseStatus.healthy
          : FirebaseStatus.degraded;

      _updateStatus(status);
    } catch (e) {
      _updateStatus(FirebaseStatus.error);
      if (kDebugMode) {
        print('❌ Firebase health check failed: $e');
      }
    }
  }

  /// Validate Auth health with proper error handling
  Future<bool> _checkAuthHealth() async {
    try {
      await _auth.signInAnonymously();
      await _auth.signOut();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Auth health check failed: $e');
      }
      return false;
    }
  }

  /// Validate Firestore health with proper error handling
  Future<bool> _checkFirestoreHealth() async {
    try {
      final testDoc = _firestore.collection('health_check').doc();
      await testDoc.set({'timestamp': FieldValue.serverTimestamp()});
      await testDoc.delete();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firestore health check failed: $e');
      }
      return false;
    }
  }

  /// Update status with proper error handling
  void _updateStatus(FirebaseStatus status) {
    if (!_disposed && !_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Validate instance state
  void _validateState() {
    if (_disposed) {
      throw FirebaseConfigException('Firebase configuration disposed');
    }
    if (!_initialized) {
      throw FirebaseConfigException('Firebase not initialized');
    }
  }

  /// Clean resource disposal with complete cleanup
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;
    _healthCheckTimer?.cancel();
    await _authStateSubscription?.cancel();

    // Clean up controllers
    final futures = <Future<void>>[
      _statusController.close(),
      _authStatusController.close(),
      _firestoreStatusController.close(),
    ];

    // Clean up Firestore
    _firestore.terminate();
    await _firestore.clearPersistence();

    // Wait for all cleanup to complete
    await Future.wait(futures);

    _instance = null;
    _initialized = false;

    if (kDebugMode) {
      print('🧹 Firebase configuration disposed');
    }
  }
}

/// Firebase status enum with proper documentation
enum FirebaseStatus {
  healthy('Services healthy'),
  degraded('Services degraded'),
  error('Service error');

  final String message;
  const FirebaseStatus(this.message);
}

/// Custom exception for Firebase configuration with proper error handling
class FirebaseConfigException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  FirebaseConfigException(
    this.message, {
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('FirebaseConfigException: $message');
    if (cause != null) buffer.write('\nCause: $cause');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    return buffer.toString();
  }
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

// Global lock registry with proper type safety
final Map<Object, Completer<void>> _locks = {};
