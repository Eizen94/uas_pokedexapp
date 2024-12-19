// lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/config/theme_config.dart';
import 'core/constants/colors.dart';
import 'core/wrappers/auth_state_wrapper.dart';
import 'features/auth/models/user_model.dart';
import 'features/auth/screens/login_screen.dart';
import 'navigation/bottom_navigation.dart';
import 'navigation/routes.dart';

/// Root application widget.
/// Configures app-wide settings and manages global state.
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
      home: Material(
        child: AuthStateWrapper(
          child: Builder(
            builder: (context) {
              final user = context.watch<UserModel?>();

              return GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: user == null
                    ? const LoginScreen()
                    : MainBottomNavigation(user: user),
              );
            },
          ),
        ),
      ),
      builder: (context, child) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        );

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
