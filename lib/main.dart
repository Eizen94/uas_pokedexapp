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

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Lock orientation to portrait
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Initialize managers
      final performanceManager = PerformanceManager();
      final monitoringManager = MonitoringManager();

      // Set global error handlers
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

      // Run app with performance monitoring
      runApp(
        performanceManager.enableSmoothAnimations(
          const PokemonApp(),
        ),
      );
    },
    (error, stack) {
      MonitoringManager().logError(
        'Uncaught Error',
        error: error,
        stackTrace: stack,
      );
    },
  );
}