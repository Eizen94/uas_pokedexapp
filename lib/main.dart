// lib/main.dart

/// Main entry point for the Pokedex application.
/// Handles application initialization, service setup, and routing.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/config/firebase_config.dart';
import 'core/config/theme_config.dart';
import 'core/utils/connectivity_manager.dart';
import 'core/utils/monitoring_manager.dart';
import 'core/utils/cache_manager.dart';
import 'core/wrappers/auth_state_wrapper.dart';
import 'features/auth/services/auth_service.dart';
import 'features/pokemon/services/pokemon_service.dart';
import 'features/favorites/services/favorite_service.dart';
import 'features/pokemon/screens/pokemon_list_screen.dart';

/// Global navigation key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Application entry point
Future<void> main() async {
  // Ensure Flutter bindings initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    await FirebaseConfig().initialize();

    // Initialize core services
    final cacheManager = await CacheManager.initialize();
    final connectivityManager = ConnectivityManager();
    final monitoringManager = MonitoringManager();

    // Initialize feature services
    final authService = AuthService();
    await authService.initialize();

    final pokemonService = await PokemonService.initialize();
    final favoriteService = await FavoriteService.initialize();

    // Initialize monitoring
    monitoringManager.logPerformanceMetric(
      type: MetricType.apiResponse,
      value: 0.0,
    );

    runApp(MultiProvider(
      providers: [
        Provider<CacheManager>.value(value: cacheManager),
        Provider<ConnectivityManager>.value(value: connectivityManager),
        Provider<MonitoringManager>.value(value: monitoringManager),
        Provider<AuthService>.value(value: authService),
        Provider<PokemonService>.value(value: pokemonService),
        Provider<FavoriteService>.value(value: favoriteService),
      ],
      child: const PokemonApp(),
    ));
  } catch (error, stackTrace) {
    monitoringManager.logError(
      'Failed to initialize app',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

/// Root application widget
class PokemonApp extends StatelessWidget {
  /// Constructor
  const PokemonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokédex',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeConfig.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AuthStateWrapper(
        child: PokemonListScreen(),
      ),
    );
  }
}