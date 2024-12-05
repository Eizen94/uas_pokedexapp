// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:uas_pokedexapp/core/config/firebase_config.dart';
import 'package:uas_pokedexapp/features/auth/screens/login_screen.dart';
import 'package:uas_pokedexapp/features/auth/screens/register_screen.dart';
import 'package:uas_pokedexapp/features/auth/screens/profile_screen.dart';
import 'package:uas_pokedexapp/features/pokemon/screens/pokemon_list_screen.dart';
import 'package:uas_pokedexapp/features/pokemon/screens/pokemon_detail_screen.dart';
import 'package:uas_pokedexapp/providers/auth_provider.dart';
import 'package:uas_pokedexapp/providers/theme_provider.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    if (kDebugMode) {
      print('🚀 Starting app initialization...');
    }

    // Initialize Firebase with proper error handling
    await FirebaseConfig.instance.initializeApp().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Firebase initialization timeout');
      },
    );

    if (kDebugMode) {
      print('✅ App initialization complete');
    }

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppAuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    if (kDebugMode) {
      print('❌ Fatal error in main: $e');
    }
    runApp(ErrorApp(error: e.toString()));
  }
}

class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Failed to start application',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(error, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    main(); // Retry initialization
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UAS Pokedex',
      debugShowCheckedModeBanner: false,
      theme: context.watch<ThemeProvider>().currentTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show loading indicator while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingScreen(
              message: 'Checking authentication...',
            );
          }

          // Show error if there's a problem with auth
          if (snapshot.hasError) {
            return ErrorScreen(
              error: snapshot.error.toString(),
              onRetry: () {
                FirebaseAuth.instance.signOut();
              },
            );
          }

          // Navigate based on auth state
          if (snapshot.hasData && snapshot.data != null) {
            if (kDebugMode) {
              print('👤 User authenticated: ${snapshot.data?.email}');
            }
            return const PokemonListScreen();
          }

          if (kDebugMode) {
            print('🔒 No authenticated user, showing login screen');
          }
          return const LoginScreen();
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/home': (context) => const PokemonListScreen(),
        '/pokemon/detail': (context) => const PokemonDetailScreen(),
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  final String message;

  const LoadingScreen({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
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
    Key? key,
    required this.error,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
