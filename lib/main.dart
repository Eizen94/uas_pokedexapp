// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:uas_pokedexapp/core/config/firebase_config.dart';
import 'package:uas_pokedexapp/core/config/theme_config.dart';
import 'package:uas_pokedexapp/core/wrappers/auth_state_wrapper.dart';
import 'package:uas_pokedexapp/features/auth/screens/login_screen.dart';
import 'package:uas_pokedexapp/features/auth/screens/register_screen.dart';
import 'package:uas_pokedexapp/features/auth/screens/profile_screen.dart';
import 'package:uas_pokedexapp/features/pokemon/screens/pokemon_list_screen.dart';
import 'package:uas_pokedexapp/features/pokemon/screens/pokemon_detail_screen.dart';
import 'package:uas_pokedexapp/features/favorites/screens/favorites_screen.dart';
import 'package:uas_pokedexapp/features/test/screens/test_screen.dart';
import 'package:uas_pokedexapp/providers/auth_provider.dart';
import 'package:uas_pokedexapp/providers/theme_provider.dart';
import 'package:uas_pokedexapp/providers/pokemon_provider.dart';
import 'package:uas_pokedexapp/widgets/loading_indicator.dart';
import 'package:uas_pokedexapp/widgets/error_dialog.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    if (kDebugMode) {
      print('🚀 Starting app initialization...');
    }

    // Initialize Firebase with proper error handling and timeout
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
          ChangeNotifierProvider(create: (_) => PokemonProvider()),
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UAS Pokedex',
      debugShowCheckedModeBanner: false,
      theme: context.watch<ThemeProvider>().currentTheme,
      home: FutureBuilder<void>(
        future: FirebaseConfig.instance.initializationComplete,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingScreen(
              message: 'Initializing app...',
            );
          }

          if (snapshot.hasError) {
            return ErrorScreen(
              error: snapshot.error.toString(),
              onRetry: () {
                FirebaseConfig.instance.reset();
                FirebaseAuth.instance.signOut();
              },
            );
          }

          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen(
                  message: 'Checking authentication...',
                );
              }

              if (snapshot.hasError) {
                return ErrorScreen(
                  error: snapshot.error.toString(),
                  onRetry: () {
                    FirebaseAuth.instance.signOut();
                  },
                );
              }

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
          );
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/home': (context) => const PokemonListScreen(),
        '/pokemon/detail': (context) => const PokemonDetailScreen(),
        '/favorites': (context) => const FavoritesScreen(),
        '/test': (context) => const TestScreen(), // Route for testing screen
      },
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeConfig.lightTheme,
      home: Scaffold(
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
                const Text(
                  'Failed to start application',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
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

class LoadingScreen extends StatelessWidget {
  final String message;

  const LoadingScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeConfig.lightTheme,
      home: Scaffold(
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeConfig.lightTheme,
      home: Scaffold(
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
      ),
    );
  }
}