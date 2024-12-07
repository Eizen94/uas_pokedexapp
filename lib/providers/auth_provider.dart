// lib/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/auth/services/auth_service.dart';

class AppAuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  Map<String, dynamic> _settings = {
    'theme': 'light',
    'language': 'en',
    'notifications': true
  };

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _user != null;
  String? get error => _error;
  Map<String, dynamic> get settings => _settings;
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  // Constructor
  AppAuthProvider() {
    _init();
  }

  // Initialize the provider
  Future<void> _init() async {
    try {
      _setLoading(true);

      _user = _authService.currentUser;

      // Listen to auth state changes
      _authService.authStateChanges.listen(_handleAuthStateChange);

      // Listen to user settings if authenticated
      if (_user != null) {
        await _loadUserSettings();
      }

      _isInitialized = true;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Handle auth state changes
  void _handleAuthStateChange(User? user) async {
    _user = user;
    if (user != null) {
      await _loadUserSettings();
    } else {
      _resetSettings();
    }
    notifyListeners();
  }

  // Reset settings to default
  void _resetSettings() {
    _settings = {'theme': 'light', 'language': 'en', 'notifications': true};
  }

  // Load user settings
  Future<void> _loadUserSettings() async {
    try {
      final doc = await _authService.getUserDocument();
      if (doc != null && doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data['settings'] != null) {
          _settings = Map<String, dynamic>.from(data['settings']);
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user settings: $e');
      }
      _resetSettings();
    }
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

      await _loadUserSettings();
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

      await _loadUserSettings();
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
      _resetSettings();
      _user = null;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Update user settings
  Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    try {
      _setLoading(true);
      _clearError();

      if (!isAuthenticated) {
        throw Exception('User must be authenticated to update settings');
      }

      await _authService.updateUserSettings(newSettings);
      _settings = Map<String, dynamic>.from(newSettings);
      notifyListeners();
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

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      _setLoading(true);
      _clearError();

      if (!isAuthenticated) {
        throw Exception('User must be authenticated to verify email');
      }

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

      if (!isAuthenticated) {
        throw Exception('User must be authenticated to delete account');
      }

      await _authService.deleteAccount(password);
      _resetSettings();
      _user = null;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // State management helpers
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

  // Utility getters
  bool get isDarkMode => _settings['theme'] == 'dark';
  String get currentLanguage => _settings['language'] as String? ?? 'en';
  bool get notificationsEnabled => _settings['notifications'] as bool? ?? true;
  bool get needsEmailVerification => _user?.emailVerified == false;
  String get userDisplayName =>
      _user?.displayName ?? _user?.email ?? 'Guest User';
  bool get hasProfilePhoto => _user?.photoURL?.isNotEmpty ?? false;
  String? get profilePhotoUrl => _user?.photoURL;
  bool get isAnonymous => _user?.isAnonymous ?? true;
  DateTime? get userCreationTime => _user?.metadata.creationTime;
  DateTime? get lastSignInTime => _user?.metadata.lastSignInTime;

  // Listen to settings changes
  Stream<DocumentSnapshot> get userSettingsStream =>
      _authService.userSettingsStream();
}
