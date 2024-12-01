// lib/core/constants/text_styles.dart

import 'package:flutter/material.dart';
import 'colors.dart';

class AppTextStyles {
  // Headings
  static TextStyle get headlineLarge => const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      );

  static TextStyle get headlineMedium => const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get headlineSmall => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      );

  // Body text
  static TextStyle get bodyLarge => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get bodySmall => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
      );

  // Special styles
  static TextStyle get buttonText => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      );

  static TextStyle get caption => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      );

  // List text styles
  static TextStyle get listTitle => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get listSubtitle => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: Colors.grey,
      );

  // Pokemon specific styles
  static TextStyle get pokemonName => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      );

  static TextStyle get pokemonNumber => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.grey,
      );

  static TextStyle get pokemonType => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle get pokemonStat => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      );

  // Error and info styles
  static TextStyle get error => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.red,
      );

  static TextStyle get info => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.blue,
      );
}
