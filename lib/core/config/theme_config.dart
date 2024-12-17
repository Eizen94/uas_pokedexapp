// lib/core/config/theme_config.dart

/// Theme configuration for the Pokedex application.
/// Defines global theme data and dynamic theming support.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/colors.dart';
import '../constants/text_styles.dart';

/// Theme configuration class
class ThemeConfig {
  const ThemeConfig._();

  /// Light theme data
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: AppColors.primaryButton,
          secondary: AppColors.secondaryButton,
          error: AppColors.error,
          surface: AppColors.cardBackground,
        ),
        scaffoldBackgroundColor: AppColors.background,
        cardTheme: CardTheme(
          color: AppColors.cardBackground,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleTextStyle: AppTextStyles.heading2,
          iconTheme: IconThemeData(
            color: AppColors.primaryText,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.cardBackground,
          selectedItemColor: AppColors.primaryButton,
          unselectedItemColor: AppColors.secondaryText,
          elevation: 8,
          type: BottomNavigationBarType.fixed,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.searchBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          hintStyle: AppTextStyles.searchPlaceholder,
        ),
        textTheme: TextTheme(
          displayLarge: AppTextStyles.heading1,
          displayMedium: AppTextStyles.heading2,
          displaySmall: AppTextStyles.heading3,
          bodyLarge: AppTextStyles.bodyLarge,
          bodyMedium: AppTextStyles.bodyMedium,
          bodySmall: AppTextStyles.bodySmall,
        ),
        dividerTheme: DividerThemeData(
          color: AppColors.divider,
          space: 1,
          thickness: 1,
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: AppColors.primaryButton,
          linearTrackColor: AppColors.searchBackground,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.cardBackground,
          contentTextStyle: AppTextStyles.bodyMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      );

  /// Get Pokemon type specific theme data
  static ThemeData getPokemonTypeTheme(String type) {
    final typeColor = _getTypeColor(type);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: typeColor,
        secondary: AppColors.secondaryButton,
        error: AppColors.error,
        surface: AppColors.cardBackground,
      ),
      scaffoldBackgroundColor: typeColor,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
    );
  }

  /// System overlay style for Pokemon detail screen
  static SystemUiOverlayStyle getPokemonDetailSystemUiStyle(String type) {
    return const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    );
  }

  /// Get color for Pokemon type badge
  static Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'bug':
        return PokemonTypeColors.bug;
      case 'dark':
        return PokemonTypeColors.dark;
      case 'dragon':
        return PokemonTypeColors.dragon;
      case 'electric':
        return PokemonTypeColors.electric;
      case 'fairy':
        return PokemonTypeColors.fairy;
      case 'fighting':
        return PokemonTypeColors.fighting;
      case 'fire':
        return PokemonTypeColors.fire;
      case 'flying':
        return PokemonTypeColors.flying;
      case 'ghost':
        return PokemonTypeColors.ghost;
      case 'grass':
        return PokemonTypeColors.grass;
      case 'ground':
        return PokemonTypeColors.ground;
      case 'ice':
        return PokemonTypeColors.ice;
      case 'normal':
        return PokemonTypeColors.normal;
      case 'poison':
        return PokemonTypeColors.poison;
      case 'psychic':
        return PokemonTypeColors.psychic;
      case 'rock':
        return PokemonTypeColors.rock;
      case 'steel':
        return PokemonTypeColors.steel;
      case 'water':
        return PokemonTypeColors.water;
      default:
        return PokemonTypeColors.normal;
    }
  }
}
