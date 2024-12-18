// lib/main.dart

/// Application entry point.
/// Initializes services and launches the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';
import 'app.dart';
import 'core/config/firebase_config.dart';
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

      // Initialize Firebase
      final firebaseConfig = FirebaseConfig();
      await firebaseConfig.initialize();

      // Initialize performance monitoring
      final performanceManager = PerformanceManager();

      // Initialize error monitoring
      final monitoringManager = MonitoringManager();

      // Set error handlers
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
      // Log any errors that occur in the zone
      MonitoringManager().logError(
        'Uncaught Error',
        error: error,
        stackTrace: stack,
      );
    },
  );
}

/// Run app in error-boundary zone
Future<void> runZonedGuarded(
  Future<void> Function() body,
  void Function(Object error, StackTrace stack) onError,
) async {
  final Zone parentZone = Zone.current;

  final ZoneSpecification specification = ZoneSpecification(
    handleUncaughtError: (Zone self, ZoneDelegate parent, Zone zone,
        Object error, StackTrace stackTrace) {
      parentZone.runBinary(onError, error, stackTrace);
    },
  );

  final Zone zone = Zone.current.fork(specification: specification);

  await zone.run<Future<void>>(() => body());
}
