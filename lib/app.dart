// lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/config/theme_config.dart';
import 'core/constants/colors.dart';
import 'core/wrappers/auth_state_wrapper.dart';
import 'features/auth/models/user_model.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'navigation/bottom_navigation.dart';
import 'navigation/routes.dart';

/// Root application widget
class PokemonApp extends StatelessWidget {
  /// Constructor
  const PokemonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokédex',
      theme: ThemeConfig.lightTheme,
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRouter.generateRoute,
      builder: (context, child) {
        // Set system UI style
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        );

        if (child == null) return const SizedBox.shrink();

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: Material(
            color: AppColors.background,
            child: child,
          ),
        );
      },
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: AuthStateWrapper(
          child: Builder(
            builder: (context) {
              return Consumer<UserModel?>(
                builder: (context, user, _) {
                  if (user == null) {
                    return const LoginScreen();
                  }

                  // Get auth service instance
                  final authService =
                      Provider.of<AuthService>(context, listen: false);

                  return MainBottomNavigation(
                    user: user,
                    authService: authService,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
