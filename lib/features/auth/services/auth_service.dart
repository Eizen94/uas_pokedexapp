// lib/features/auth/services/auth_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

/// Enhanced authentication service with proper resource management, security,
/// and error handling
class AuthService {
  // Singleton with thread-safe initialization
  static AuthService? _instance;
  static final _lock = Lock();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final _streamSubscriptions = <StreamSubscription>[];
  bool _isInitialized = false;
  bool _disposed = false;

  // Private constructor
  AuthService._internal(this._auth, this._firestore);

  // Thread-safe singleton getter
  static Future<AuthService> get instance async {
    if (_instance == null) {
      await _lock.synchronized(() async {
        _instance ??= AuthService._internal(
          FirebaseAuth.instance,
          FirebaseFirestore.instance,
        );
        await _instance!._initialize();
      });
    }
    return _instance!;
  }

  // Service initialization
  Future<void> _initialize() async {
    if (_isInitialized || _disposed) return;

    try {
      // Setup persistence
      await _auth.setPersistence(Persistence.LOCAL);

      // Setup Firestore settings
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      _isInitialized = true;

      if (kDebugMode) {
        print('✅ AuthService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ AuthService initialization failed: $e');
      }
      rethrow;
    }
  }

  // Auth state changes stream with resource management
  Stream<User?> get authStateChanges {
    _throwIfDisposed();
    return _auth.authStateChanges();
  }

  // Current user with null safety
  User? get currentUser {
    _throwIfDisposed();
    return _auth.currentUser;
  }

  // Enhanced sign in with proper error handling and validation
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _throwIfDisposed();
    _validateInputs(email: email, password: password);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Create/update user document with audit trail
      if (credential.user != null) {
        await _updateUserDocument(credential.user!, {
          'lastLogin': FieldValue.serverTimestamp(),
          'lastLoginDevice': await _getDeviceInfo(),
        });
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Enhanced registration with security validations
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _throwIfDisposed();
    _validateInputs(email: email, password: password);

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Setup initial user document with security rules
      if (credential.user != null) {
        await _createUserDocument(credential.user!);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Clean sign out with proper cleanup
  Future<void> signOut() async {
    _throwIfDisposed();

    try {
      final user = currentUser;
      if (user != null) {
        await _updateUserDocument(user, {
          'lastSignOut': FieldValue.serverTimestamp(),
        });
      }

      await _auth.signOut();
      _clearCache();
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Secure user document creation
  Future<void> _createUserDocument(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);

    final userData = {
      'uid': user.uid,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
      'deviceInfo': await _getDeviceInfo(),
      'settings': _getDefaultSettings(),
    };

    await userDoc.set(userData, SetOptions(merge: true));
  }

  // Safe user document update
  Future<void> _updateUserDocument(User user, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(user.uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Input validation
  void _validateInputs({required String email, required String password}) {
    if (email.isEmpty || password.isEmpty) {
      throw const AuthValidationException('Email and password are required');
    }

    if (!email.contains('@') || email.length < 5) {
      throw const AuthValidationException('Invalid email format');
    }

    if (password.length < 6) {
      throw const AuthValidationException(
          'Password must be at least 6 characters');
    }
  }

  // Default user settings
  Map<String, dynamic> _getDefaultSettings() {
    return {
      'theme': 'light',
      'notifications': true,
      'language': 'en',
    };
  }

  // Device info for audit
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    return {
      'platform': defaultTargetPlatform.toString(),
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  // Cache cleanup
  void _clearCache() {
    // Clear any cached data
  }

  // Error handling with proper error types
  Exception _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      return AuthException(
        code: error.code,
        message: _getErrorMessage(error.code),
      );
    }
    if (error is AuthValidationException) {
      return error;
    }
    return AuthException(
      code: 'unknown',
      message: 'An unexpected authentication error occurred',
    );
  }

  // Localized error messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Invalid password';
      case 'email-already-in-use':
        return 'Email is already registered';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email format';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts, please try again later';
      default:
        return 'Authentication error occurred';
    }
  }

  // Resource cleanup
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;
    for (final sub in _streamSubscriptions) {
      await sub.cancel();
    }
    _streamSubscriptions.clear();
    _instance = null;
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw StateError('AuthService has been disposed');
    }
  }
}

// Custom exceptions for better error handling
class AuthException implements Exception {
  final String code;
  final String message;

  const AuthException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'AuthException: $message (code: $code)';
}

class AuthValidationException implements Exception {
  final String message;

  const AuthValidationException(this.message);

  @override
  String toString() => 'AuthValidationException: $message';
}
