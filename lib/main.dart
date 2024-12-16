// lib/main.dart

/// Entry point and initialization for Pokedex application.
/// Handles core services setup and application configuration.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/config/firebase_config.dart';
import 'core/config/theme_config.dart';
import 'core/utils/connectivity_manager.dart';
import 'core/wrappers/auth_state_wrapper.dart';
import 'features/auth/models/user_model.dart';
import 'features/auth/services/auth_service.dart';
import 'features/pokemon/services/pokemon_service.dart';
import 'features/favorites/services/favorite_service.dart';
import 'features/pokemon/screens/pokemon_list_screen.dart';

/// Global navigator key for app-wide navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Entry point of the application
Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Configure system UI
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // Initialize Firebase
    await Firebase.initializeApp();
    final firebaseConfig = FirebaseConfig();
    await firebaseConfig.initialize();

    // Initialize core services
    final connectivityManager = ConnectivityManager();
    final authService = AuthService();
    await authService.initialize();
    
    final pokemonService = await PokemonService.initialize();
    final favoriteService = await FavoriteService.initialize();

    // Setup error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    };

    runApp(
      MultiProvider(
        providers: [
          Provider<FirebaseConfig>.value(value: firebaseConfig),
          Provider<AuthService>.value(value: authService),
          Provider<PokemonService>.value(value: pokemonService),
          Provider<FavoriteService>.value(value: favoriteService),
          Provider<ConnectivityManager>.value(value: connectivityManager),
          // Add Stream provider for user state
          StreamProvider<UserModel?>(
            create: (_) => authService.userStream,
            initialData: null,
          ),
        ],
        child: PokedexApp(
          firebaseConfig: firebaseConfig,
          authService: authService,
        ),
      ),
    );
  } catch (error, stackTrace) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace);
    debugPrint('Initialization error: $error');
    rethrow;
  }
}

/// Root application widget
class PokedexApp extends StatelessWidget {
  /// Firebase configuration
  final FirebaseConfig firebaseConfig;
  
  /// Authentication service
  final AuthService authService;

  /// Constructor
  const PokedexApp({
    required this.firebaseConfig,
    required this.authService,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Get current user from provider
    final user = context.watch<UserModel?>();

    return MaterialApp(
      title: 'Pokédex',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeConfig.lightTheme,
      home: AuthStateWrapper(
        firebaseConfig: firebaseConfig,
        authService: authService,
        child: user != null 
          ? PokemonListScreen(user: user)
          : const Center(child: CircularProgressIndicator()),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}