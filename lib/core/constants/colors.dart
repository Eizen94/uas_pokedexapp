// lib/core/constants/colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFFDC0A2D); // Classic Pokedex Red
  static const Color primaryDark = Color(0xFFAE0927); // Darker Pokedex Red
  static const Color primaryLight = Color(0xFFFF4C4C); // Lighter Pokedex Red
  static const Color accent = Color(0xFFFFCB05); // Pokemon Yellow

  // Background colors
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // Card colors
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color cardShadowLight = Color(0x1A000000);
  static const Color cardShadowDark = Color(0x1AFFFFFF);

  // Text colors
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF666666);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB3B3B3);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFDC3545);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);

  // Stats colors
  static const Color statHp = Color(0xFFFF5959);
  static const Color statAttack = Color(0xFFF5AC78);
  static const Color statDefense = Color(0xFFFAE078);
  static const Color statSpAtk = Color(0xFF9DB7F5);
  static const Color statSpDef = Color(0xFFA7DB8D);
  static const Color statSpeed = Color(0xFFFA92B2);

  // Pokemon type colors
  static final Map<String, Color> typeColors = {
    'normal': const Color(0xFFA8A878),
    'fire': const Color(0xFFF08030),
    'water': const Color(0xFF6890F0),
    'electric': const Color(0xFFF8D030),
    'grass': const Color(0xFF78C850),
    'ice': const Color(0xFF98D8D8),
    'fighting': const Color(0xFFC03028),
    'poison': const Color(0xFFA040A0),
    'ground': const Color(0xFFE0C068),
    'flying': const Color(0xFFA890F0),
    'psychic': const Color(0xFFF85888),
    'bug': const Color(0xFFA8B820),
    'rock': const Color(0xFFB8A038),
    'ghost': const Color(0xFF705898),
    'dragon': const Color(0xFF7038F8),
    'dark': const Color(0xFF705848),
    'steel': const Color(0xFFB8B8D0),
    'fairy': const Color(0xFFEE99AC),
  };

  // Type background colors (lighter versions for backgrounds)
  static final Map<String, Color> typeBackgroundColors = {
    'normal': const Color(0xFFBCBCAC),
    'fire': const Color(0xFFF5AC78),
    'water': const Color(0xFF9DB7F5),
    'electric': const Color(0xFFFAE078),
    'grass': const Color(0xFFA7DB8D),
    'ice': const Color(0xFFBCE6E6),
    'fighting': const Color(0xFFD67873),
    'poison': const Color(0xFFC183C1),
    'ground': const Color(0xFFEBD69D),
    'flying': const Color(0xFFC6B7F5),
    'psychic': const Color(0xFFFA92B2),
    'bug': const Color(0xFFC6D16E),
    'rock': const Color(0xFFD1C17D),
    'ghost': const Color(0xFFA292BC),
    'dragon': const Color(0xFFA27DFA),
    'dark': const Color(0xFFA29288),
    'steel': const Color(0xFFD1D1E0),
    'fairy': const Color(0xFFF4BDC9),
  };

  // Stat value colors (for progress bars)
  static Color getStatColor(int value) {
    if (value < 50) return error;
    if (value < 100) return warning;
    return success;
  }

  // Gradient colors for type backgrounds
  static List<Color> getTypeGradient(String type) {
    final mainColor = typeColors[type.toLowerCase()] ?? typeColors['normal']!;
    final darkColor = _darken(mainColor, 0.1);
    final lightColor = _lighten(mainColor, 0.1);
    return [darkColor, mainColor, lightColor];
  }

  // Helper method to lighten a color
  static Color _lighten(Color color, [double amount = 0.3]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  // Helper method to darken a color
  static Color _darken(Color color, [double amount = 0.3]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
