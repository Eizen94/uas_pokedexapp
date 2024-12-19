// main.dart yang perlu diperbaiki:

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Tambahkan import yang diperlukan
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/utils/monitoring_manager.dart';
import 'core/utils/performance_manager.dart';
// Tambahkan provider yang dibutuhkan
import 'providers/auth_provider.dart';
import 'providers/pokemon_provider.dart';
import 'providers/theme_provider.dart';

void main() {
  runZonedGuarded(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();

        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);

        // Initialize managers
        final performanceManager = PerformanceManager();
        final monitoringManager = MonitoringManager();

        // Set error handler untuk Flutter errors
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

        // Error handler untuk Platform/Framework errors - perbaikan untuk error PlatformDispatcher
        ErrorWidget.builder = (FlutterErrorDetails details) {
          monitoringManager.logError(
            'Framework Error',
            error: details.exception,
            stackTrace: details.stack,
          );
          return Material(
            child: Center(
              child: Text(
                'An error occurred.\n${details.exception}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        };

        // Run app dengan MultiProvider sesuai providers yang ada
        runApp(
          MultiProvider(
            providers: [
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
