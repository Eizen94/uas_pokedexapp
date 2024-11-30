// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../features/auth/services/auth_service.dart';

class AppAuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  String? _error;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  // Constructor
  AppAuthProvider() {
    _init();
  }

  // Initialize the provider
  Future<void> _init() async {
    _user = _authService.currentUser;
    notifyListeners();

    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  // Sign in with email and password
  Future<void> signIn(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Sign up with email and password
  Future<void> signUp(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.signOut();
      _user = null;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.sendPasswordResetEmail(email);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Update profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );

      _user = _authService.currentUser;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.sendEmailVerification();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Delete account
  Future<void> deleteAccount(String password) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.deleteAccount(password);
      _user = null;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Check if user needs to verify email
  bool get needsEmailVerification {
    return _user != null && !_user!.emailVerified;
  }

  // Get user display name or email
  String get userDisplayName {
    if (_user?.displayName?.isNotEmpty ?? false) {
      return _user!.displayName!;
    }
    return _user?.email ?? 'Guest User';
  }

  // Check if user has profile photo
  bool get hasProfilePhoto {
    return _user?.photoURL?.isNotEmpty ?? false;
  }

  // Get profile photo URL
  String? get profilePhotoUrl => _user?.photoURL;

  // Check if user is anonymous
  bool get isAnonymous => _user?.isAnonymous ?? true;

  // Get user creation time
  DateTime? get userCreationTime => _user?.metadata.creationTime;

  // Get last sign in time
  DateTime? get lastSignInTime => _user?.metadata.lastSignInTime;
}
