// lib/providers/auth_provider.dart

/// Authentication provider to manage user authentication state.
/// Handles user session and provides auth state across the app.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../features/auth/models/user_model.dart';
import '../services/firebase_service.dart';

/// Authentication state
enum AuthState {
  /// Initial state
  initial,

  /// User is authenticated
  authenticated,

  /// User is not authenticated
  unauthenticated,

  /// Error state
  error
}

/// Authentication provider
class AuthProvider with ChangeNotifier {
  // Dependencies
  final FirebaseService _firebaseService;

  // Internal state
  AuthState _state = AuthState.initial;
  UserModel? _user;
  String? _error;
  StreamSubscription<UserModel?>? _authSubscription;

  /// Constructor
  AuthProvider({
    FirebaseService? firebaseService,
  }) : _firebaseService = firebaseService ?? FirebaseService() {
    _initialize();
  }

  /// Current auth state
  AuthState get state => _state;

  /// Current user
  UserModel? get user => _user;

  /// Error message
  String? get error => _error;

  /// Whether user is authenticated
  bool get isAuthenticated => _user != null;

  /// Initialize provider
  Future<void> _initialize() async {
    try {
      await _firebaseService.initialize();

      _authSubscription = _firebaseService.userStream.listen(
        _handleAuthStateChange,
        onError: _handleError,
      );
    } catch (e) {
      _handleError(e);
    }
  }

  /// Sign in with email and password
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _state = AuthState.initial;
      _error = null;
      notifyListeners();

      await _firebaseService.signInWithEmail(
        email: email,
        password: password,
      );
    } catch (e) {
      _handleError(e);
    }
  }

  /// Register with email and password
  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _state = AuthState.initial;
      _error = null;
      notifyListeners();

      await _firebaseService.registerWithEmail(
        email: email,
        password: password,
      );
    } catch (e) {
      _handleError(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _firebaseService.signOut();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      if (_user == null) {
        throw Exception('No authenticated user');
      }

      final updatedUser = await _firebaseService.updateProfile(
        displayName: displayName,
        photoUrl: photoUrl,
      );

      _user = updatedUser;
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseService.sendPasswordResetEmail(email);
    } catch (e) {
      _handleError(e);
    }
  }

  /// Handle auth state changes
  void _handleAuthStateChange(UserModel? user) {
    _user = user;
    _state = user != null ? AuthState.authenticated : AuthState.unauthenticated;
    _error = null;
    notifyListeners();
  }

  /// Handle errors
  void _handleError(dynamic error) {
    _state = AuthState.error;
    _error = error.toString();
    notifyListeners();

    if (kDebugMode) {
      print('🚫 Auth Error: $error');
    }
  }

  /// Check if error is specific type
  bool hasError(String errorType) {
    return _error?.contains(errorType) ?? false;
  }

  /// Clear error state
  void clearError() {
    _error = null;
    _state =
        _user != null ? AuthState.authenticated : AuthState.unauthenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
