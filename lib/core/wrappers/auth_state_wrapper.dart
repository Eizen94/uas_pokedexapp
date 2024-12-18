// lib/core/wrappers/auth_state_wrapper.dart

/// Authentication state wrapper to manage user authentication state.
/// Provides unified authentication state management across the application.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../config/firebase_config.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/auth/services/auth_service.dart';

/// Wrapper for authentication state management
class AuthStateWrapper extends StatefulWidget {
  /// Child widget to be wrapped
  final Widget child;

  /// Constructor
  const AuthStateWrapper({
    required this.child,
    super.key,
  });

  @override
  State<AuthStateWrapper> createState() => _AuthStateWrapperState();
}

class _AuthStateWrapperState extends State<AuthStateWrapper> {
  late final FirebaseConfig _firebaseConfig;
  late final AuthService _authService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _firebaseConfig = FirebaseConfig();
      await _firebaseConfig.initialize();

      _authService = AuthService(
        firebaseConfig: _firebaseConfig,
      );
      await _authService.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize auth services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: _firebaseConfig.auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        // Convert Firebase User to UserModel
        final UserModel? user = snapshot.hasData
            ? UserModel.fromFirebaseUser(snapshot.data!)
            : null;

        // Provide user model to app
        return Provider<UserModel?>.value(
          value: user,
          child: StreamBuilder<bool>(
            stream: _authService.isInitializedStream,
            builder: (context, initSnapshot) {
              // Wait for auth service initialization
              if (!initSnapshot.hasData || !initSnapshot.data!) {
                return const MaterialApp(
                  home: Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              }

              return widget.child;
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }
}

/// Extension methods for AuthStateWrapper
extension AuthStateWrapperExtension on BuildContext {
  /// Get current user model
  UserModel? get currentUser => Provider.of<UserModel?>(this, listen: false);

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Stream of authentication state changes
  Stream<UserModel?> get authStateChanges {
    final user = Provider.of<UserModel?>(this, listen: true);
    if (user == null) {
      return Stream.value(null);
    }
    return Stream.value(user);
  }
}

/// Authentication state change callback type
typedef AuthStateChangeCallback = void Function(UserModel? user);

/// Authentication error callback type
typedef AuthErrorCallback = void Function(String error);

/// Mixin for handling auth state changes
mixin AuthStateHandler<T extends StatefulWidget> on State<T> {
  StreamSubscription<UserModel?>? _authSubscription;

  /// Handle auth state changes
  void onAuthStateChanged(UserModel? user) {}

  /// Handle auth errors
  void onAuthError(String error) {}

  @override
  void initState() {
    super.initState();
    _authSubscription = context.authStateChanges.listen(
      onAuthStateChanged,
      onError: (error) => onAuthError(error.toString()),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
