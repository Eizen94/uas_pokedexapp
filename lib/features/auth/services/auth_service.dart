// lib/features/auth/services/auth_service.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/subjects.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/utils/monitoring_manager.dart';
import '../models/user_model.dart';

/// Authentication service errors
class AuthError {
  static const String invalidEmail = 'Invalid email address';
  static const String weakPassword = 'Password is too weak';
  static const String emailInUse = 'Email already in use';
  static const String invalidCredentials = 'Invalid email or password';
  static const String userNotFound = 'User not found';
  static const String networkError = 'Network error occurred';
  static const String unknownError = 'An unknown error occurred';
}

/// Authentication service class
class AuthService {
  static final AuthService _instance = AuthService._internal();

  /// Factory constructor
  factory AuthService({
    required FirebaseConfig firebaseConfig,
    MonitoringManager? monitoringManager,
  }) {
    _instance._firebaseConfig = firebaseConfig;
    _instance._monitoringManager = monitoringManager ?? MonitoringManager();
    return _instance;
  }

  AuthService._internal();

  late final FirebaseConfig _firebaseConfig;
  late final MonitoringManager _monitoringManager;
  final BehaviorSubject<bool> _isInitializedController =
      BehaviorSubject<bool>.seeded(false);
  bool _disposed = false;

  /// Stream of initialization state
  Stream<bool> get isInitializedStream => _isInitializedController.stream;

  /// Stream of current user
  Stream<UserModel?> get userStream =>
      _firebaseConfig.auth.authStateChanges().map((user) {
        return user != null ? UserModel.fromFirebaseUser(user) : null;
      });

  /// Current user
  UserModel? get currentUser {
    final user = _firebaseConfig.auth.currentUser;
    return user != null ? UserModel.fromFirebaseUser(user) : null;
  }

  /// Initialize service
  Future<void> initialize() async {
    if (_disposed) {
      throw StateError('AuthService has been disposed');
    }

    try {
      await _firebaseConfig.initialized;
      _isInitializedController.add(true);

      if (kDebugMode) {
        print('✅ Auth service initialized');
      }
    } catch (e) {
      _monitoringManager.logError(
        'Auth service initialization failed',
        error: e,
      );
      _isInitializedController.add(false);
      throw AuthError.unknownError;
    }
  }

  /// Verify user's email address
  Future<void> verifyEmail() async {
    try {
      final user = _firebaseConfig.auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
      } else {
        throw AuthError.userNotFound;
      }
    } catch (e) {
      _monitoringManager.logError('Email verification failed', error: e);
      throw AuthError.unknownError;
    }
  }

  /// Sign in with email and password
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential =
          await _firebaseConfig.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: AuthError.userNotFound,
        );
      }

      return UserModel.fromFirebaseUser(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      _monitoringManager.logError(
        'Sign in failed',
        error: e,
        additionalData: {'email': email},
      );

      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
          throw AuthError.invalidCredentials;
        case 'invalid-email':
          throw AuthError.invalidEmail;
        case 'network-request-failed':
          throw AuthError.networkError;
        default:
          throw AuthError.unknownError;
      }
    }
  }

  /// Register with email and password
  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential =
          await _firebaseConfig.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw FirebaseAuthException(
          code: 'registration-failed',
          message: AuthError.unknownError,
        );
      }

      await userCredential.user!.sendEmailVerification();
      return UserModel.fromFirebaseUser(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      _monitoringManager.logError(
        'Registration failed',
        error: e,
        additionalData: {'email': email},
      );

      switch (e.code) {
        case 'email-already-in-use':
          throw AuthError.emailInUse;
        case 'invalid-email':
          throw AuthError.invalidEmail;
        case 'weak-password':
          throw AuthError.weakPassword;
        case 'network-request-failed':
          throw AuthError.networkError;
        default:
          throw AuthError.unknownError;
      }
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _firebaseConfig.auth.signOut();
    } catch (e) {
      _monitoringManager.logError('Sign out failed', error: e);
      throw AuthError.unknownError;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseConfig.auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      _monitoringManager.logError(
        'Password reset failed',
        error: e,
        additionalData: {'email': email},
      );

      switch (e.code) {
        case 'user-not-found':
          throw AuthError.userNotFound;
        case 'invalid-email':
          throw AuthError.invalidEmail;
        case 'network-request-failed':
          throw AuthError.networkError;
        default:
          throw AuthError.unknownError;
      }
    }
  }

  /// Update user profile
  Future<UserModel> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final user = _firebaseConfig.auth.currentUser;
      if (user == null) {
        throw AuthError.userNotFound;
      }

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      return UserModel.fromFirebaseUser(user);
    } catch (e) {
      _monitoringManager.logError('Profile update failed', error: e);
      throw AuthError.unknownError;
    }
  }

  /// Clean up resources
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _isInitializedController.close();
  }
}
