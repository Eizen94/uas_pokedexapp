// lib/app.dart

/// Root application widget.
/// Configures app-wide settings and manages global state.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/config/firebase_config.dart';
import 'core/config/theme_config.dart';
import 'core/wrappers/auth_state_wrapper.dart';
import 'features/auth/models/user_model.dart';
import 'features/auth/screens/login_screen.dart';
import 'navigation/bottom_navigation.dart';
import 'navigation/routes.dart';

/// Root application widget
class PokemonApp extends StatelessWidget {
  /// Constructor
  const PokemonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseConfig>(
          create: (_) => FirebaseConfig(),
        ),
      ],
      child: AuthStateWrapper(
        child: MaterialApp(
          title: 'Pokédex',
          theme: ThemeConfig.lightTheme,
          debugShowCheckedModeBanner: false,
          onGenerateRoute: AppRouter.generateRoute,
          builder: (context, child) {
            // Set system UI overlay style
            SystemChrome.setSystemUIOverlayStyle(
              const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                systemNavigationBarColor: Colors.white,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
            );

            // Set preferred orientations
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ]);

            return child ?? const SizedBox.shrink();
          },
          home: const _AuthenticationHandler(),
        ),
      ),
    );
  }
}

/// Authentication state handler widget
class _AuthenticationHandler extends StatelessWidget {
  /// Constructor
  const _AuthenticationHandler();

  @override
  Widget build(BuildContext context) {
    return Consumer<UserModel?>(
      builder: (context, user, _) {
        // Show loading indicator while checking auth state
        if (user == null) {
          return const LoginScreen();
        }

        // Show main navigation for authenticated users
        return MainBottomNavigation(user: user);
      },
    );
  }
}
