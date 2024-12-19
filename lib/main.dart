// lib/main.dart

/// Application entry point.
/// Initializes services and launches the app.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/utils/monitoring_manager.dart';
import 'core/utils/performance_manager.dart';

/// Main entry point of the application
void main() {
  // Wrap the app in a guarded zone for error handling
  runZonedGuarded(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();

        // Lock orientation to portrait
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);

        // Initialize managers
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

        // Set up error handler for Platform errors
        PlatformDispatcher.instance.onError = (error, stack) {
          monitoringManager.logError(
            'Platform Error',
            error: error,
            stackTrace: stack,
          );
          return true;
        };

        // Run app with performance monitoring
        runApp(
          performanceManager.enableSmoothAnimations(
            const PokemonApp(),
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
      // Log any unhandled errors that occur in the Zone
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
