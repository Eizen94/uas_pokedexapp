// lib/core/constants/text_styles.dart

import 'package:flutter/material.dart';
import 'colors.dart';

/// Typography system optimized for Pokemon UI based on Material Design principles.
/// Provides consistent text styling across the app.
class AppTextStyles {
  /// Main Headings

  /// Heading 1 - Primary screen titles (e.g. "Pokédex")
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryLight,
    height: 1.2,
  );

  /// Heading 2 - Section headers (e.g. "Base Stats", "Evolution")
  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.3,
  );

  /// Heading 3 - Card titles and important text (e.g. Pokemon names in list)
  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.4,
  );

  /// Body Text Styles

  /// Body Large - Primary reading text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimaryLight,
    height: 1.5,
  );

  /// Body Medium - Secondary reading text and descriptions
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimaryLight,
    height: 1.5,
  );

  /// Body Small - Supporting text, captions, and metadata
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondaryLight,
    height: 1.5,
  );

  /// Pokemon Specific Styles

  /// Pokemon Name - Used in Pokemon cards and detail view
  static const TextStyle pokemonName = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: AppColors.textPrimaryLight,
    height: 1.2,
  );

  /// Pokemon Number - Pokedex number display (e.g. "#001")
  static const TextStyle pokemonNumber = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondaryLight,
    letterSpacing: 1,
    height: 1.2,
  );

  /// Pokemon Type Label - Used in type badges
  static const TextStyle pokemonType = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.5,
    height: 1.2,
  );

  /// Pokemon Stats - Used in stats display
  static const TextStyle pokemonStat = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimaryLight,
    height: 1.4,
  );

  /// Pokemon Description - Used for Pokemon descriptions and flavor text
  static const TextStyle pokemonDescription = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimaryLight,
    height: 1.6,
    letterSpacing: 0.2,
  );

  /// UI Component Styles

  /// Button Text - Used for buttons and interactive elements
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: Colors.white,
    height: 1.25,
  );

  /// Search Input - Used for search bar text
  static const TextStyle searchInput = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.15,
    color: AppColors.textPrimaryLight,
    height: 1.4,
  );

  /// Dark Theme Variants

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

  /// Dark theme variant for pokemonDescription
  static TextStyle get pokemonDescriptionDark => pokemonDescription.copyWith(
        color: AppColors.textPrimaryDark,
      );

  /// Dark theme variant for searchInput
  static TextStyle get searchInputDark => searchInput.copyWith(
        color: AppColors.textPrimaryDark,
      );

  /// Helper Methods

  /// Get appropriate text style based on theme brightness
  static TextStyle getResponsiveStyle(TextStyle style, Brightness brightness) {
    if (brightness == Brightness.dark) {
      return style.copyWith(
        color: AppColors.textPrimaryDark,
      );
    }
    return style;
  }

  /// Private constructor to prevent instantiation
  const AppTextStyles._();
}
