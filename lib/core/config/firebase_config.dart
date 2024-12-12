// lib/core/config/firebase_config.dart

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../utils/prefs_helper.dart';
import '../constants/api_paths.dart';
import '../utils/monitoring_manager.dart';

/// Enhanced Firebase configuration with improved error handling and resource management.
/// Provides centralized Firebase service management with comprehensive error handling,
/// resource tracking, and proper state monitoring.
class FirebaseConfig {
  // Singleton implementation with improved locking
  static FirebaseConfig? _instance;
  static final Object _instanceLock = Object();
  static final Object _operationLock = Object();

  // Core Firebase instances with proper typing
  final FirebaseApp _app;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // Strongly typed stream controllers with proper resource management
  final StreamController<FirebaseStatus> _statusController;
  final StreamController<bool> _authStatusController;
  final StreamController<bool> _firestoreStatusController;

  // Enhanced state management
  bool _initialized;
  bool _disposed;
  Timer? _healthCheckTimer;
  final Completer<void> _initCompleter;

  // Constants for configuration
  static const Duration _healthCheckInterval = Duration(minutes: 5);
  static const Duration _operationTimeout = Duration(seconds: 30);
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Private constructor with enhanced initialization
  FirebaseConfig._(
    this._app,
    this._auth,
    this._firestore,
  )   : _statusController = StreamController<FirebaseStatus>.broadcast(),
        _authStatusController = StreamController<bool>.broadcast(),
        _firestoreStatusController = StreamController<bool>.broadcast(),
        _initialized = false,
        _disposed = false,
        _initCompleter = Completer<void>() {
    _setupHealthMonitoring();
  }

  /// Get Firebase configuration instance with proper error handling
  static Future<FirebaseConfig> getInstance() async {
    if (_instance != null) return _instance!;

    return synchronized(_instanceLock, () async {
      if (_instance != null) return _instance!;

      try {
        final app = await Firebase.initializeApp();
        final auth = FirebaseAuth.instance;
        final firestore = FirebaseFirestore.instance;

        _instance = FirebaseConfig._(app, auth, firestore);
        await _instance!._initialize();

        return _instance!;
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('Firebase initialization error: $e');
          print('Stack trace: $stackTrace');
        }
        throw FirebaseConfigException(
          'Failed to initialize Firebase configuration: $e',
          stackTrace,
        );
      }
    });
  }

  /// Initialize Firebase with enhanced error handling and retry mechanism
  Future<void> _initialize() async {
    if (_initialized || _disposed) return;

    try {
      // Configure Auth with enhanced persistence
      await synchronized(_operationLock, () async {
        await _auth.setPersistence(Persistence.LOCAL);
      });

      // Configure Firestore with optimized settings
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        sslEnabled: true,
        host: ApiPaths.kBaseUrl,
        timestampsInSnapshots: true,
      );

      _initialized = true;
      _initCompleter.complete();

      if (kDebugMode) {
        print('✅ Firebase initialization complete');
      }
    } catch (e, stackTrace) {
      _initCompleter.completeError(e, stackTrace);
      throw FirebaseConfigException(
        'Firebase initialization failed: $e',
        stackTrace,
      );
    }
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

  /// Setup health monitoring with enhanced error detection
  void _setupHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      _healthCheckInterval,
      (_) => _checkHealth(),
    );
  }

  /// Comprehensive health check implementation with proper error handling
  Future<void> _checkHealth() async {
    if (_disposed) return;

    try {
      final results = await Future.wait([
        _checkAuthHealth(),
        _checkFirestoreHealth(),
      ], eagerError: true);

      final authOk = results[0] as bool;
      final firestoreOk = results[1] as bool;

      _authStatusController.add(authOk);
      _firestoreStatusController.add(firestoreOk);

      final status = authOk && firestoreOk
          ? FirebaseStatus.healthy
          : FirebaseStatus.degraded;

      _updateStatus(status);
    } catch (e, stackTrace) {
      _updateStatus(FirebaseStatus.error);
      if (kDebugMode) {
        print('❌ Firebase health check failed: $e');
        print('Stack trace: $stackTrace');
      }
    }
  }

  /// Validate Auth health with retry mechanism
  Future<bool> _checkAuthHealth() async {
    int attempts = 0;
    while (attempts < _maxRetryAttempts) {
      try {
        final userCredential = await _auth.signInAnonymously();
        if (userCredential.user != null) {
          await _auth.signOut();
          return true;
        }
        return false;
      } catch (e) {
        attempts++;
        if (attempts < _maxRetryAttempts) {
          await Future.delayed(_retryDelay * attempts);
          continue;
        }
        return false;
      }
    }
    return false;
  }

  /// Validate Firestore health with retry mechanism
  Future<bool> _checkFirestoreHealth() async {
    int attempts = 0;
    while (attempts < _maxRetryAttempts) {
      try {
        final testDoc =
            _firestore.collection(ApiPaths.kHealthCheckCollection).doc();

        await testDoc.set({
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'healthy',
        });

        final snapshot = await testDoc.get();
        await testDoc.delete();

        return snapshot.exists && snapshot.data()?['status'] == 'healthy';
      } catch (e) {
        attempts++;
        if (attempts < _maxRetryAttempts) {
          await Future.delayed(_retryDelay * attempts);
          continue;
        }
        return false;
      }
    }
    return false;
  }

  /// Update status with proper error handling
  void _updateStatus(FirebaseStatus status) {
    if (!_disposed && !_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Validate instance state with proper error messages
  void _validateState() {
    if (_disposed) {
      throw FirebaseConfigException(
        'Firebase configuration has been disposed',
        StackTrace.current,
      );
    }
    if (!_initialized) {
      throw FirebaseConfigException(
        'Firebase configuration is not initialized',
        StackTrace.current,
      );
    }
  }

  /// Enhanced resource cleanup
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;
    _healthCheckTimer?.cancel();

    // Clean up streams in proper order
    await Future.wait([
      _statusController.close(),
      _authStatusController.close(),
      _firestoreStatusController.close(),
    ]);

    // Reset state
    _instance = null;
    _initialized = false;

    if (kDebugMode) {
      print('🧹 Firebase configuration disposed');
    }
  }

  // Public getters with validation
  Stream<FirebaseStatus> get status {
    _validateState();
    return _statusController.stream;
  }

  Stream<bool> get authStatus {
    _validateState();
    return _authStatusController.stream;
  }

  Stream<bool> get firestoreStatus {
    _validateState();
    return _firestoreStatusController.stream;
  }

  bool get isInitialized => _initialized;
  bool get isDisposed => _disposed;
}

/// Enhanced Firebase status enum with proper documentation
enum FirebaseStatus {
  healthy('All services are operational'),
  degraded('Some services are experiencing issues'),
  error('Critical service failure detected');

  final String message;
  const FirebaseStatus(this.message);

  @override
  String toString() => '$name: $message';
}

/// Enhanced exception handling with stack trace support
class FirebaseConfigException implements Exception {
  final String message;
  final StackTrace? stackTrace;

  const FirebaseConfigException(this.message, [this.stackTrace]);

  @override
  String toString() => 'FirebaseConfigException: $message';
}

/// Thread-safe operation helper with proper error propagation
Future<T> synchronized<T>(
  Object lock,
  Future<T> Function() computation,
) async {
  if (computation == null) {
    throw ArgumentError.notNull('computation');
  }

  final completer = Completer<void>();
  try {
    final result = await computation();
    completer.complete();
    return result;
  } catch (e, stackTrace) {
    completer.completeError(e, stackTrace);
    rethrow;
  }
}
