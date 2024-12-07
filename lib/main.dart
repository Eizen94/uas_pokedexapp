// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:uas_pokedexapp/core/config/firebase_config.dart';
import 'package:uas_pokedexapp/core/config/theme_config.dart';
import 'package:uas_pokedexapp/core/wrappers/auth_state_wrapper.dart';
import 'package:uas_pokedexapp/features/auth/screens/login_screen.dart';
import 'package:uas_pokedexapp/features/auth/screens/register_screen.dart';
import 'package:uas_pokedexapp/features/auth/screens/profile_screen.dart';
import 'package:uas_pokedexapp/features/pokemon/screens/pokemon_list_screen.dart';
import 'package:uas_pokedexapp/features/pokemon/screens/pokemon_detail_screen.dart';
import 'package:uas_pokedexapp/features/test/screens/test_screen.dart';
import 'package:uas_pokedexapp/providers/auth_provider.dart';
import 'package:uas_pokedexapp/providers/theme_provider.dart';
import 'package:uas_pokedexapp/providers/pokemon_provider.dart';
import 'package:uas_pokedexapp/widgets/loading_indicator.dart';

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
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AppAuthProvider()),
          // Initialize PokemonProvider after auth is ready
          ChangeNotifierProxyProvider<AppAuthProvider, PokemonProvider>(
            create: (_) => PokemonProvider(),
            update: (_, auth, pokemon) => pokemon!..updateAuth(auth),
          ),
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
      home: const AuthStateWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/home': (context) => const PokemonListScreen(),
        '/pokemon/detail': (context) => const PokemonDetailScreen(),
        '/test': (context) => const TestScreen(),
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