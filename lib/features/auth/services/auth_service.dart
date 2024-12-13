// lib/features/auth/services/auth_service.dart

/// Authentication service to handle user authentication operations.
/// Manages login, registration, and auth state persistence.
library features.auth.services.auth_service;

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
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
  final FirebaseAuth _auth;
  final FirebaseConfig _firebaseConfig;
  final MonitoringManager _monitoringManager;

  final BehaviorSubject<bool> _isInitializedController =
      BehaviorSubject<bool>.seeded(false);

  /// Constructor
  const AuthService({
    FirebaseAuth? auth,
    FirebaseConfig? firebaseConfig,
    MonitoringManager? monitoringManager,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firebaseConfig = firebaseConfig ?? FirebaseConfig(),
        _monitoringManager = monitoringManager ?? MonitoringManager();

  /// Stream of initialization state
  Stream<bool> get isInitializedStream => _isInitializedController.stream;

  /// Current user stream
  Stream<UserModel?> get userStream => _auth.authStateChanges().map((user) {
        return user != null ? UserModel.fromFirebaseUser(user) : null;
      });

  /// Current user
  UserModel? get currentUser {
    final user = _auth.currentUser;
    return user != null ? UserModel.fromFirebaseUser(user) : null;
  }

  /// Sign in with email and password
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
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
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw FirebaseAuthException(
          code: 'registration-failed',
          message: AuthError.unknownError,
        );
      }

      // Send email verification
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

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      _monitoringManager.logError('Sign out failed', error: e);
      throw AuthError.unknownError;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
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

  /// Verify email
  Future<void> verifyEmail() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      _monitoringManager.logError('Email verification failed', error: e);
      throw AuthError.unknownError;
    }
  }

  /// Update user profile
  Future<UserModel> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthError.userNotFound;
      }

      await user.updateDisplayName(displayName);
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      return UserModel.fromFirebaseUser(user);
    } catch (e) {
      _monitoringManager.logError('Profile update failed', error: e);
      throw AuthError.unknownError;
    }
  }

  /// Initialize service
  Future<void> initialize() async {
    try {
      await _firebaseConfig.initialize();
      _isInitializedController.add(true);
    } catch (e) {
      _monitoringManager.logError('Auth service initialization failed',
          error: e);
      _isInitializedController.add(false);
      throw AuthError.unknownError;
    }
  }

  /// Dispose resources
  void dispose() {
    _isInitializedController.close();
  }
}
