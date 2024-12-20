// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/config/firebase_config.dart';
import 'core/utils/monitoring_manager.dart';
import 'core/utils/performance_manager.dart';
import 'core/utils/cache_manager.dart';
import 'features/auth/services/auth_service.dart';
import 'features/pokemon/services/pokemon_service.dart';
import 'providers/auth_provider.dart';
import 'providers/pokemon_provider.dart';
import 'providers/theme_provider.dart';

/// Main entry point of the application
void main() {
  runZonedGuarded(
    () async {
      try {
        debugPrint('Starting app initialization...');

        // Initialize Flutter bindings
        WidgetsFlutterBinding.ensureInitialized();
        debugPrint('Flutter binding initialized');

        // Lock orientation to portrait
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        debugPrint('Device orientation locked');

        // Initialize managers first
        debugPrint('Initializing managers...');
        final performanceManager = PerformanceManager();
        final monitoringManager = MonitoringManager();
        debugPrint('Managers initialized');

        // Initialize core services in order
        debugPrint('Initializing core services...');
        final cacheManager = await CacheManager.initialize();
        debugPrint('Cache manager initialized');

        final firebaseConfig = FirebaseConfig();
        debugPrint('Firebase initialization started');
        await firebaseConfig.initialize();
        debugPrint('Firebase initialized successfully');

        // Initialize feature services
        debugPrint('Initializing feature services...');
        final authService = AuthService(firebaseConfig: firebaseConfig);
        await authService.initialize();
        debugPrint('Auth service initialized');

        final pokemonService = await PokemonService.initialize();
        debugPrint('Pokemon service initialized');

        // Set global error handlers for Flutter errors
        FlutterError.onError = (FlutterErrorDetails details) {
          debugPrint('Flutter error occurred: ${details.exception}');
          monitoringManager.logError(
            'Flutter Error',
            error: details.exception,
            additionalData: {
              'stack': details.stack.toString(),
              'library': details.library,
            },
          );
        };

        // Set error widget builder for Framework errors
        ErrorWidget.builder = (FlutterErrorDetails details) {
          debugPrint('Framework error occurred: ${details.exception}');
          monitoringManager.logError(
            'Framework Error',
            error: details.exception,
            stackTrace: details.stack,
          );
          return Material(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'An error occurred',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      details.exception.toString(),
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        };

        debugPrint('Starting app with providers...');

        // Run app with all required providers
        runApp(
          MultiProvider(
            providers: [
              // Core providers
              Provider<FirebaseConfig>.value(value: firebaseConfig),
              Provider<MonitoringManager>.value(value: monitoringManager),
              Provider<CacheManager>.value(value: cacheManager),

              // Service providers
              Provider<AuthService>.value(value: authService),
              Provider<PokemonService>.value(value: pokemonService),

              // State providers
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              ChangeNotifierProvider(create: (_) => PokemonProvider()),
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ],
            child: performanceManager.enableSmoothAnimations(
              const PokemonApp(),
            ),
          ),
        );

        debugPrint('App started successfully');
      } catch (e, stack) {
        debugPrint('Error during initialization: $e');
        debugPrint('Stack trace: $stack');
        MonitoringManager().logError(
          'Initialization Error',
          error: e,
          stackTrace: stack,
        );
        rethrow;
      }
    },
    (error, stack) {
      debugPrint('Uncaught error: $error');
      debugPrint('Stack trace: $stack');
      MonitoringManager().logError(
        'Uncaught Error',
        error: error,
        stackTrace: stack,
        additionalData: {
          'type': 'zone_error',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    },
  );
}
