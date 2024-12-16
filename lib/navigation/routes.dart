// lib/navigation/routes.dart

/// Route definitions and navigation configuration.
/// Handles app-wide routing and navigation state.
library;

import 'package:flutter/material.dart';

import '../features/auth/models/user_model.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/profile_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/pokemon/models/pokemon_model.dart';
import '../features/pokemon/screens/pokemon_detail_screen.dart';
import '../features/pokemon/screens/pokemon_list_screen.dart';
import '../features/favorites/screens/favorites_screen.dart';

/// App route names
class Routes {
  const Routes._();

  /// Login screen route
  static const String login = '/login';

  /// Register screen route
  static const String register = '/register';

  /// Profile screen route
  static const String profile = '/profile';

  /// Pokemon list screen route
  static const String pokemonList = '/pokemon';

  /// Pokemon detail screen route
  static const String pokemonDetail = '/pokemon/detail';

  /// Favorites screen route
  static const String favorites = '/favorites';
}

/// App route configuration
class AppRouter {
  const AppRouter._();

  /// Generate route based on settings
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      case Routes.register:
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
          settings: settings,
        );

      case Routes.profile:
        final user = settings.arguments as UserModel?;
        if (user == null) {
          return _errorRoute('User data required');
        }
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );

      case Routes.pokemonList:
        final user = settings.arguments as UserModel?;
        if (user == null) {
          return _errorRoute('User data required');
        }
        return MaterialPageRoute(
          builder: (_) => PokemonListScreen(user: user),
          settings: settings,
        );

      case Routes.pokemonDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null) {
          return _errorRoute('Pokemon data required');
        }
        final pokemon = args['pokemon'] as PokemonModel?;
        final user = args['user'] as UserModel?;
        if (pokemon == null || user == null) {
          return _errorRoute('Invalid pokemon detail arguments');
        }
        return MaterialPageRoute(
          builder: (_) => PokemonDetailScreen(
            pokemon: pokemon,
            user: user,
          ),
          settings: settings,
        );

      case Routes.favorites:
        final user = settings.arguments as UserModel?;
        if (user == null) {
          return _errorRoute('User data required');
        }
        return MaterialPageRoute(
          builder: (_) => FavoritesScreen(user: user),
          settings: settings,
        );

      default:
        return _errorRoute('Route not found');
    }
  }

  /// Create error route
  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  /// Navigation helpers
  static void navigateTo(BuildContext context, String route,
      {Object? arguments}) {
    Navigator.pushNamed(context, route, arguments: arguments);
  }

  static void replaceTo(BuildContext context, String route,
      {Object? arguments}) {
    Navigator.pushReplacementNamed(context, route, arguments: arguments);
  }

  static void popToRoot(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  static void pop(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  /// Route guard for authenticated routes
  static bool requiresAuth(String route) {
    return route != Routes.login && route != Routes.register;
  }
}
