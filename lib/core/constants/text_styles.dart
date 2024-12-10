// lib/core/constants/text_styles.dart

import 'package:flutter/material.dart';
import 'colors.dart';

class AppTextStyles {
  // Headings with proper scaling and accessibility
  static TextStyle get headlineLarge => TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: AppColors.textPrimaryLight,
      );

  static TextStyle get headlineMedium => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimaryLight,
      );

  static TextStyle get headlineSmall => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryLight,
      );

  // Body text with readability optimization
  static TextStyle get bodyLarge => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimaryLight,
      );

  static TextStyle get bodyMedium => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimaryLight,
      );

  static TextStyle get bodySmall => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimaryLight,
      );

  // Special styles for interactive elements
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
        color: AppColors.textSecondaryLight,
      );

  // List text styles for hierarchy
  static TextStyle get listTitle => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryLight,
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
        color: AppColors.textPrimaryLight,
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
        color: AppColors.textPrimaryLight,
      );

  // Title styles for consistency
  static TextStyle get titleLarge => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimaryLight,
      );

  static TextStyle get titleMedium => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryLight,
      );

  static TextStyle get titleSmall => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimaryLight,
      );

  // Error and info styles
  static TextStyle get error => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.error,
      );

  static TextStyle get info => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.blue,
      );

  // Dark theme variants
  static TextStyle get headlineLargeDark => headlineLarge.copyWith(
        color: AppColors.textPrimaryDark,
      );

  static TextStyle get headlineMediumDark => headlineMedium.copyWith(
        color: AppColors.textPrimaryDark,
      );

  static TextStyle get headlineSmallDark => headlineSmall.copyWith(
        color: AppColors.textPrimaryDark,
      );

  static TextStyle get bodyLargeDark => bodyLarge.copyWith(
        color: AppColors.textPrimaryDark,
      );

  static TextStyle get bodyMediumDark => bodyMedium.copyWith(
        color: AppColors.textPrimaryDark,
      );

  static TextStyle get bodySmallDark => bodySmall.copyWith(
        color: AppColors.textPrimaryDark,
      );

  static TextStyle get listTitleDark => listTitle.copyWith(
        color: AppColors.textPrimaryDark,
      );

  static TextStyle get pokemonNameDark => pokemonName.copyWith(
        color: AppColors.textPrimaryDark,
      );

  static TextStyle get pokemonStatDark => pokemonStat.copyWith(
        color: AppColors.textPrimaryDark,
      );

  // Private constructor to prevent instantiation
  const AppTextStyles._();
}
