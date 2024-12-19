// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/config/firebase_config.dart';
import 'core/utils/monitoring_manager.dart';
import 'core/utils/performance_manager.dart';
import 'providers/auth_provider.dart';
import 'providers/pokemon_provider.dart';
import 'providers/theme_provider.dart';
import 'features/auth/services/auth_service.dart';

/// Main entry point of the application
void main() {
  runZonedGuarded(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();

        // Lock orientation to portrait
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);

        // Initialize core services
        final firebaseConfig = FirebaseConfig();
        await firebaseConfig.initialize();

        final authService = AuthService(firebaseConfig: firebaseConfig);
        await authService.initialize();

        final performanceManager = PerformanceManager();
        final monitoringManager = MonitoringManager();

        // Set global error handlers for Flutter errors
        FlutterError.onError = (FlutterErrorDetails details) {
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

        // Run app with all required providers
        runApp(
          MultiProvider(
            providers: [
              Provider<FirebaseConfig>.value(value: firebaseConfig),
              Provider<AuthService>.value(value: authService),
              Provider<MonitoringManager>.value(value: monitoringManager),
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              ChangeNotifierProvider(create: (_) => PokemonProvider()),
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ],
            child: performanceManager.enableSmoothAnimations(
              const PokemonApp(),
            ),
          ),
        );
      } catch (e, stack) {
        debugPrint('Error during initialization: $e');
        MonitoringManager().logError(
          'Initialization Error',
          error: e,
          stackTrace: stack,
        );
        rethrow;
      }
    },
    (error, stack) {
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
