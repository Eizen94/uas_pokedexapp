// lib/core/constants/colors.dart

import 'package:flutter/material.dart';

/// Complete color system for Pokemon app with proper organization.
/// All colors are strictly typed and immutable.
class AppColors {
  /// Brand Colors - Primary theme colors
  static const Color primary = Color(0xFFDC0A2D); // Pokemon Red
  static const Color secondary = Color(0xFF2B73B9); // Pokemon Blue
  static const Color accent = Color(0xFFFFCB05); // Pokemon Yellow

  /// Background Colors
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  /// Text Colors
  static const Color textPrimaryLight = Color(0xFF2D2D2D);
  static const Color textSecondaryLight = Color(0xFF666666);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB3B3B3);

  /// Pokemon Type Colors - Official colors for each type
  static const Map<String, Color> typeColors = {
    'normal': Color(0xFFA8A878),
    'fire': Color(0xFFF08030),
    'water': Color(0xFF6890F0),
    'electric': Color(0xFFF8D030),
    'grass': Color(0xFF78C850),
    'ice': Color(0xFF98D8D8),
    'fighting': Color(0xFFC03028),
    'poison': Color(0xFFA040A0),
    'ground': Color(0xFFE0C068),
    'flying': Color(0xFFA890F0),
    'psychic': Color(0xFFF85888),
    'bug': Color(0xFFA8B820),
    'rock': Color(0xFFB8A038),
    'ghost': Color(0xFF705898),
    'dragon': Color(0xFF7038F8),
    'dark': Color(0xFF705848),
    'steel': Color(0xFFB8B8D0),
    'fairy': Color(0xFFEE99AC),
  };

  /// Pokemon Type Background Colors - Lighter variants for cards and backgrounds
  static const Map<String, Color> typeBackgroundColors = {
    'normal': Color(0xFFBCBCAC),
    'fire': Color(0xFFF5AC78),
    'water': Color(0xFF9DB7F5),
    'electric': Color(0xFFFAE078),
    'grass': Color(0xFFA7DB8D),
    'ice': Color(0xFFBCE6E6),
    'fighting': Color(0xFFD67873),
    'poison': Color(0xFFC183C1),
    'ground': Color(0xFFEBD69D),
    'flying': Color(0xFFC6B7F5),
    'psychic': Color(0xFFFA92B2),
    'bug': Color(0xFFC6D16E),
    'rock': Color(0xFFD1C17D),
    'ghost': Color(0xFFA292BC),
    'dragon': Color(0xFFA27DFA),
    'dark': Color(0xFFA29288),
    'steel': Color(0xFFD1D1E0),
    'fairy': Color(0xFFF4BDC9),
  };

  /// Pokemon Stats Colors - Colors for stat visualization
  static const Color statHp = Color(0xFFFF5959);
  static const Color statAttack = Color(0xFFF5AC78);
  static const Color statDefense = Color(0xFFFAE078);
  static const Color statSpAtk = Color(0xFF9DB7F5);
  static const Color statSpDef = Color(0xFFA7DB8D);
  static const Color statSpeed = Color(0xFFFA92B2);

  /// Status Colors - For UI feedback
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFDC3545);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);

  /// Helper Methods

  /// Get color for Pokemon type
  /// Returns normal type color as fallback
  static Color getTypeColor(String type) {
    return typeColors[type.toLowerCase()] ?? typeColors['normal']!;
  }

  /// Get background color for Pokemon type
  /// Returns normal type background as fallback
  static Color getTypeBackgroundColor(String type) {
    return typeBackgroundColors[type.toLowerCase()] ??
        typeBackgroundColors['normal']!;
  }

  /// Get gradient colors for Pokemon type
  /// Returns array of colors from light to dark
  static List<Color> getTypeGradient(String type) {
    final baseColor = getTypeColor(type);
    return [
      _lighten(baseColor, 0.1),
      baseColor,
      _darken(baseColor, 0.1),
    ];
  }

  /// Get color for stat value
  /// Returns color based on stat value range
  static Color getStatColor(int value) {
    if (value >= 150) return success;
    if (value >= 90) return info;
    if (value >= 40) return warning;
    return error;
  }

  /// Get progress indicator color based on percentage
  static Color getProgressColor(double percentage) {
    if (percentage >= 0.8) return success;
    if (percentage >= 0.6) return info;
    if (percentage >= 0.4) return warning;
    return error;
  }

  /// Lighten a color by specified amount
  /// Amount should be between 0 and 1
  static Color _lighten(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// Darken a color by specified amount
  /// Amount should be between 0 and 1
  static Color _darken(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// Get appropriate text color for background
  /// Returns light or dark text color based on background brightness
  static Color getTextColorForBackground(Color backgroundColor) {
    return ThemeData.estimateBrightnessForColor(backgroundColor) ==
            Brightness.light
        ? textPrimaryLight
        : textPrimaryDark;
  }

  /// Private constructor to prevent instantiation
  const AppColors._();
}
