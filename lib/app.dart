// app.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
        // Add any additional providers needed for app-wide state
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

            // Return the child widget or a fallback widget
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
        // Show login screen if user is not authenticated
        if (user == null) {
          debugPrint('User not authenticated. Showing LoginScreen.');
          return const LoginScreen();
        }

        // Show main navigation for authenticated users
        debugPrint(
            'User authenticated: ${user.displayName}. Showing MainBottomNavigation.');
        return MainBottomNavigation(user: user);
      },
    );
  }
}
