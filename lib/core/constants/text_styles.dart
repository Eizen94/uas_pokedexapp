// lib/core/constants/text_styles.dart

import 'package:flutter/material.dart';
import 'colors.dart';

/// Complete typography system with proper scaling and accessibility support
class AppTextStyles {
  // Main Typography Styles

  /// Heading 1 - Used for main screen titles
  static TextStyle get h1 => const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: AppColors.textPrimaryLight,
        height: 1.2,
      );

  /// Heading 2 - Used for section headers
  static TextStyle get h2 => const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimaryLight,
        height: 1.3,
      );

  /// Heading 3 - Used for card titles and important text
  static TextStyle get h3 => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryLight,
        height: 1.4,
      );

  /// Body Large - Primary reading text
  static TextStyle get bodyLarge => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimaryLight,
        height: 1.5,
      );

  /// Body Medium - Secondary reading text
  static TextStyle get bodyMedium => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimaryLight,
        height: 1.5,
      );

  /// Body Small - Supporting text and captions
  static TextStyle get bodySmall => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondaryLight,
        height: 1.5,
      );

  // Pokemon Specific Styles

  /// Pokemon Name - Used in Pokemon cards and detail view
  static TextStyle get pokemonName => const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: AppColors.textPrimaryLight,
        height: 1.2,
      );

  /// Pokemon Number - Pokedex number display
  static TextStyle get pokemonNumber => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondaryLight,
        letterSpacing: 1,
        height: 1.2,
      );

  /// Pokemon Type Label - Used in type badges
  static TextStyle get pokemonType => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.5,
        height: 1.2,
      );

  /// Pokemon Stat Label - Used in stats display
  static TextStyle get pokemonStat => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimaryLight,
        height: 1.4,
      );

  /// Pokemon Description - Used for Pokemon descriptions
  static TextStyle get pokemonDescription => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimaryLight,
        height: 1.6,
        letterSpacing: 0.2,
      );

  // UI Component Styles

  /// Button Text - Used for buttons and interactive elements
  static TextStyle get button => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Colors.white,
        height: 1.25,
      );

  /// Caption - Used for supporting information
  static TextStyle get caption => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: AppColors.textSecondaryLight,
        height: 1.33,
      );

  /// Tab Label - Used for tab bars
  static TextStyle get tabLabel => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.2,
      );

  /// Search Input - Used for search bars
  static TextStyle get searchInput => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.15,
        color: AppColors.textPrimaryLight,
        height: 1.4,
      );

  // Dark Theme Variants

  /// Dark theme variant for h1
  static TextStyle get h1Dark => h1.copyWith(
        color: AppColors.textPrimaryDark,
      );

  /// Dark theme variant for h2
  static TextStyle get h2Dark => h2.copyWith(
        color: AppColors.textPrimaryDark,
      );

  /// Dark theme variant for h3
  static TextStyle get h3Dark => h3.copyWith(
        color: AppColors.textPrimaryDark,
      );

  /// Dark theme variant for bodyLarge
  static TextStyle get bodyLargeDark => bodyLarge.copyWith(
        color: AppColors.textPrimaryDark,
      );

  /// Dark theme variant for bodyMedium
  static TextStyle get bodyMediumDark => bodyMedium.copyWith(
        color: AppColors.textPrimaryDark,
      );

  /// Dark theme variant for bodySmall
  static TextStyle get bodySmallDark => bodySmall.copyWith(
        color: AppColors.textSecondaryDark,
      );

  /// Dark theme variant for pokemonName
  static TextStyle get pokemonNameDark => pokemonName.copyWith(
        color: AppColors.textPrimaryDark,
      );

  /// Dark theme variant for pokemonNumber
  static TextStyle get pokemonNumberDark => pokemonNumber.copyWith(
        color: AppColors.textSecondaryDark,
      );

  /// Dark theme variant for pokemonStat
  static TextStyle get pokemonStatDark => pokemonStat.copyWith(
        color: AppColors.textPrimaryDark,
      );

  /// Dark theme variant for pokemonDescription
  static TextStyle get pokemonDescriptionDark => pokemonDescription.copyWith(
        color: AppColors.textPrimaryDark,
      );

  /// Dark theme variant for searchInput
  static TextStyle get searchInputDark => searchInput.copyWith(
        color: AppColors.textPrimaryDark,
      );

  // Helper Methods

  /// Get appropriate text style based on theme brightness
  static TextStyle getResponsiveStyle(TextStyle style, Brightness brightness) {
    if (brightness == Brightness.dark) {
      return style.copyWith(
        color: AppColors.textPrimaryDark,
      );
    }
    return style;
  }

  // Private constructor to prevent instantiation
  const AppTextStyles._();
}
