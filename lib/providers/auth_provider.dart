// lib/providers/auth_provider.dart

import 'dart:async';
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

  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<DocumentSnapshot>? _settingsSubscription;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _user != null;
  String? get error => _error;
  Map<String, dynamic> get settings => Map.unmodifiable(_settings);
  Stream<User?> get authStateChanges =>
      FirebaseAuth.instance.authStateChanges();
  Stream<DocumentSnapshot> get userSettingsStream =>
      _authService.userSettingsStream();

  bool _disposed = false;

  // Constructor
  AppAuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      _user = _authService.currentUser ;

      // Setup auth state listener
      _authStateSubscription =
          FirebaseAuth.instance.authStateChanges().listen((User ? user) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _user = user;
          if (user != null) {
            _loadUser Settings().then((_) {
              _setupSettingsListener();
              if (!_disposed) {
                notifyListeners();
              }
            });
          } else {
            _resetSettings();
            _settingsSubscription?.cancel();
            if (!_disposed) {
              notifyListeners();
            }
          }
        });
      });

      if (_user != null) {
        await _loadUser Settings();
        _setupSettingsListener();
      }

      _isInitialized = true;
      if (!_disposed) {
        notifyListeners();
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _error = e.toString();
        if (!_disposed) {
          notifyListeners();
        }
      });
    }
  }

  void _setupSettingsListener() {
    _settingsSubscription?.cancel();
    if (_user != null) {
      _settingsSubscription = userSettingsStream.listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          if (data != null && data['settings'] != null) {
            _settings = Map<String, dynamic>.from(data['settings']);
            if (!_disposed) {
              notifyListeners();
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authStateSubscription?.cancel();
    _settingsSubscription?.cancel();
    super.dispose();
  }

  void _resetSettings() {
    _settings = {'theme': 'light', 'language': 'en', 'notifications': true};
  }

  Future<void> _loadUser Settings() async {
    if (_user == null) return;

    try {
      final doc = await _authService.getUser Document();
      if (doc != null && doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data['settings'] != null) {
          _settings = Map<String, dynamic>.from(data['settings']);
          if (!_disposed) {
            notifyListeners();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user settings: $e');
      }
      _resetSettings();
    }
  }

  Future<void> signIn(String email, String password) async {
    if (_disposed) return;

    try {
      _isLoading = true;
      if (!_disposed) notifyListeners();

      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> signUp(String email, String password) async {
    if (_disposed) return;

    try {
            _isLoading = true;
      if (!_disposed) notifyListeners();

      await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
      );

      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> signOut() async {
    if (_disposed) return;

    try {
      _isLoading = true;
      if (!_disposed) notifyListeners();

      await _authService.signOut();
      // Auth state changes will handle the rest
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> resetPassword(String email) async {
    if (_disposed) return;

    try {
      _isLoading = true;
      if (!_disposed) notifyListeners();

      await _authService.sendPasswordResetEmail(email);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> sendEmailVerification() async {
    if (_disposed || !isAuthenticated) return;

    try {
      _isLoading = true;
      if (!_disposed) notifyListeners();

      await _authService.sendEmailVerification();
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> deleteAccount(String password) async {
    if (_disposed || !isAuthenticated) return;

    try {
      _isLoading = true;
      if (!_disposed) notifyListeners();

      await _authService.deleteAccount(password);
      // Auth state changes will handle the rest
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    if (_disposed || !isAuthenticated) return;

    try {
      _isLoading = true;
      if (!_disposed) notifyListeners();

      await _authService.updateUser Settings(newSettings);
      _settings = Map<String, dynamic>.from(newSettings);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
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
}