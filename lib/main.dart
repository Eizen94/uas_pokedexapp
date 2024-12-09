// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:uas_pokedexapp/core/config/firebase_config.dart';
import 'package:uas_pokedexapp/core/config/theme_config.dart';
import 'package:uas_pokedexapp/features/auth/screens/login_screen.dart';
import 'package:uas_pokedexapp/features/auth/screens/register_screen.dart';
import 'package:uas_pokedexapp/features/auth/screens/profile_screen.dart';
import 'package:uas_pokedexapp/features/pokemon/screens/pokemon_list_screen.dart';
import 'package:uas_pokedexapp/features/pokemon/screens/pokemon_detail_screen.dart';
import 'package:uas_pokedexapp/dev/tools/test_screen.dart';
import 'package:uas_pokedexapp/dev/tools/dev_tools.dart';
import 'package:uas_pokedexapp/providers/auth_provider.dart';
import 'package:uas_pokedexapp/providers/theme_provider.dart';
import 'package:uas_pokedexapp/providers/pokemon_provider.dart';
import 'package:uas_pokedexapp/widgets/loading_indicator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (DevTools.isDevMode) {
    await DevTools().initialize();
  }

  runApp(const AppRoot());
  try {
    if (kDebugMode) {
      print('🚀 Starting app initialization...');
    }

    await FirebaseConfig.instance.initializeApp().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Firebase initialization timeout');
      },
    );

    if (kDebugMode) {
      print('✅ App initialization complete');
    }

    runApp(const AppRoot());
  } catch (e) {
    if (kDebugMode) {
      print('❌ Fatal error in main: $e');
    }
    runApp(ErrorApp(error: e.toString()));
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AppAuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => PokemonProvider(),
        ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'UAS Pokedex',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentTheme,
      home: const AuthenticationHandler(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/home': (context) => const PokemonListScreen(),
        '/pokemon/detail': (context) => const PokemonDetailScreen(),
        '/test': (context) => const TestScreen(),
        '/dev/test': (context) => DevTools.getTestScreen(),
      },
    );
  }
}

class AuthenticationHandler extends StatelessWidget {
  const AuthenticationHandler({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: context.read<AppAuthProvider>().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: LoadingIndicator(
                message: 'Checking authentication...',
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
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
                    'Authentication Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          if (kDebugMode) {
            print('👤 User authenticated: ${user.email}');
          }
          return const PokemonListScreen();
        }

        return const LoginScreen();
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
                    main();
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
