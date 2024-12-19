// lib/core/wrappers/auth_state_wrapper.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Get already initialized instances from provider
      _firebaseConfig = Provider.of<FirebaseConfig>(context, listen: false);
      _authService = Provider.of<AuthService>(context, listen: false);
      await _authService.initialized;

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isInitialized = false;
        });
      }
      debugPrint('Failed to initialize auth services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Error: $_error',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _initializeServices,
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<auth.User?>(
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

        final UserModel? user = snapshot.hasData
            ? UserModel.fromFirebaseUser(snapshot.data!)
            : null;

        return Provider<UserModel?>.value(
          value: user,
          child: StreamBuilder<bool>(
            stream: _authService.isInitializedStream,
            builder: (context, initSnapshot) {
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
}

/// Extension methods for AuthStateWrapper
extension AuthStateWrapperExtension on BuildContext {
  /// Get current user model
  UserModel? get currentUser => Provider.of<UserModel?>(this, listen: false);

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Stream of authentication state changes
  Stream<UserModel?> get authStateChanges {
    return Provider.of<UserModel?>(this, listen: true) == null
        ? Stream.value(null)
        : Stream.value(Provider.of<UserModel?>(this, listen: true));
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
