// lib/core/wrappers/auth_state_wrapper.dart

/// Authentication state wrapper to manage user authentication state.
/// Provides unified authentication state management across the application.
library core.wrappers.auth_state_wrapper;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../config/firebase_config.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/auth/services/auth_service.dart';

/// Wrapper for authentication state management
class AuthStateWrapper extends StatelessWidget {
  /// Child widget to be wrapped
  final Widget child;

  /// Firebase configuration instance
  final FirebaseConfig _firebaseConfig;
  
  /// Auth service instance
  final AuthService _authService;

  /// Constructor
  const AuthStateWrapper({
    super.key,
    required this.child,
    FirebaseConfig? firebaseConfig,
    AuthService? authService,
  }) : _firebaseConfig = firebaseConfig ?? FirebaseConfig(),
       _authService = authService ?? const AuthService();

  @override
  Widget build(BuildContext context) {
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

              return child;
            },
          ),
        );
      },
    );
  }
}

/// Extension methods for AuthStateWrapper
extension AuthStateWrapperExtension on BuildContext {
  /// Get current user model
  UserModel? get currentUser => Provider.of<UserModel?>(this, listen: false);
  
  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;
  
  /// Stream of authentication state changes
  Stream<UserModel?> get authStateChanges => 
      Provider.of<UserModel?>(this, listen: true).asStream();
}

/// Authentication state change callback type
typedef AuthStateChangeCallback = void Function(UserModel? user);

/// Authentication error callback type
typedef AuthErrorCallback = void Function(String error);

/// Mixin for handling auth state changes
mixin AuthStateHandler<T extends StatefulWidget> on State<T> {
  /// Handle auth state changes
  void onAuthStateChanged(UserModel? user) {}
  
  /// Handle auth errors
  void onAuthError(String error) {}
  
  @override
  void initState() {
    super.initState();
    context.authStateChanges.listen(
      onAuthStateChanged,
      onError: (error) => onAuthError(error.toString()),
    );
  }
}