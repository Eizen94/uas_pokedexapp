// lib/main.dart

/// Entry point and initialization for Pokedex application.
/// Handles core services setup and application configuration.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/config/firebase_config.dart';
import 'core/config/theme_config.dart';
import 'core/wrappers/auth_state_wrapper.dart';
import 'features/auth/services/auth_service.dart';
import 'features/pokemon/services/pokemon_service.dart';
import 'features/favorites/services/favorite_service.dart';
import 'features/pokemon/screens/pokemon_list_screen.dart';

/// Entry point of the application
Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Configure system UI
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    // Initialize Firebase
    await Firebase.initializeApp();
    final firebaseConfig = FirebaseConfig();
    await firebaseConfig.initialize();

    // Initialize services
    final authService = AuthService();
    await authService.initialize();
    
    final pokemonService = await PokemonService.initialize();
    final favoriteService = await FavoriteService.initialize();

    runApp(
      MultiProvider(
        providers: [
          Provider<AuthService>(create: (_) => authService),
          Provider<PokemonService>(create: (_) => pokemonService),
          Provider<FavoriteService>(create: (_) => favoriteService),
        ],
        child: const PokedexApp(),
      ),
    );
  } catch (error) {
    debugPrint('Initialization error: $error');
    rethrow;
  }
}

/// Root application widget
class PokedexApp extends StatelessWidget {
  /// Constructor
  const PokedexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokédex',
      debugShowCheckedModeBanner: false,
      theme: ThemeConfig.lightTheme,
      home: const AuthStateWrapper(
        child: PokemonListScreen(),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}   