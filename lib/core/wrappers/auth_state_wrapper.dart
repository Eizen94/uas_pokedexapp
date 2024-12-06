// lib/core/wrappers/auth_state_wrapper.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/pokemon/screens/pokemon_list_screen.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/error_dialog.dart';
import 'package:flutter/foundation.dart';

class AuthStateWrapper extends StatefulWidget {
  const AuthStateWrapper({super.key});

  @override
  State<AuthStateWrapper> createState() => _AuthStateWrapperState();
}

class _AuthStateWrapperState extends State<AuthStateWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen(
            message: 'Checking authentication...',
          );
        }

        // Handle error state
        if (snapshot.hasError) {
          return ErrorScreen(
            error: snapshot.error.toString(),
            onRetry: () {
              FirebaseAuth.instance.signOut();
            },
          );
        }

        // Handle authenticated state
        if (snapshot.hasData && snapshot.data != null) {
          if (kDebugMode) {
            print('👤 User authenticated: ${snapshot.data?.email}');
          }
          return const PokemonListScreen();
        }

        // Handle unauthenticated state
        if (kDebugMode) {
          print('🔒 No authenticated user, showing login screen');
        }
        return const LoginScreen();
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  final String message;

  const LoadingScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LoadingIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const ErrorScreen({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Error: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
