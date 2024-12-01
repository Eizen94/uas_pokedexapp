// lib/core/constants/text_styles.dart

import 'package:flutter/material.dart';
import 'colors.dart';

class AppTextStyles {
  // Headings
  static TextStyle get headlineLarge => TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: AppColors.textLight,
      );

  static TextStyle get headlineMedium => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textLight,
      );

  static TextStyle get headlineSmall => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
      );

  // Body text
  static TextStyle get bodyLarge => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.textLight,
      );

  static TextStyle get bodyMedium => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.textLight,
      );

  static TextStyle get bodySmall => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppColors.textLight,
      );

  // Special styles
  static TextStyle get buttonText => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Colors.white,
      );

  static TextStyle get caption => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: AppColors.textLight,
      );

  // List text styles
  static TextStyle get listTitle => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
      );

  static TextStyle get listSubtitle => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: Colors.grey,
      );

  // Pokemon specific styles
  static TextStyle get pokemonName => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: AppColors.textLight,
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

  static TextStyle get pokemonStat => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textLight,
      );

  // Error and info styles
  static TextStyle get error => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.primary,
      );

  static TextStyle get info => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.blue,
      );

  // Dark theme variants
  static TextStyle get headlineLargeDark => headlineLarge.copyWith(
        color: AppColors.textDark,
      );

  static TextStyle get headlineMediumDark => headlineMedium.copyWith(
        color: AppColors.textDark,
      );

  static TextStyle get headlineSmallDark => headlineSmall.copyWith(
        color: AppColors.textDark,
      );

  static TextStyle get bodyLargeDark => bodyLarge.copyWith(
        color: AppColors.textDark,
      );

  static TextStyle get bodyMediumDark => bodyMedium.copyWith(
        color: AppColors.textDark,
      );

  static TextStyle get bodySmallDark => bodySmall.copyWith(
        color: AppColors.textDark,
      );

  static TextStyle get listTitleDark => listTitle.copyWith(
        color: AppColors.textDark,
      );

  static TextStyle get pokemonNameDark => pokemonName.copyWith(
        color: AppColors.textDark,
      );

  static TextStyle get pokemonStatDark => pokemonStat.copyWith(
        color: AppColors.textDark,
      );
}
