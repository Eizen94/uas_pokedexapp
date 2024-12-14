// lib/core/constants/text_styles.dart

/// Text style constants for the Pokedex application.
/// Defines consistent typography throughout the app.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Core text styles used across all screens and components
class AppTextStyles {
  const AppTextStyles._();

  /// Base font family
  static String get _baseFont => GoogleFonts.poppins().fontFamily!;

  /// Heading styles
  static final TextStyle heading1 = TextStyle(
    fontFamily: _baseFont,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryText,
    height: 1.2,
  );

  static final TextStyle heading2 = TextStyle(
    fontFamily: _baseFont,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    height: 1.3,
  );

  static final TextStyle heading3 = TextStyle(
    fontFamily: _baseFont,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    height: 1.4,
  );

  /// Body text styles
  static final TextStyle bodyLarge = TextStyle(
    fontFamily: _baseFont,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryText,
    height: 1.5,
  );

  static final TextStyle bodyMedium = TextStyle(
    fontFamily: _baseFont,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryText,
    height: 1.5,
  );

  static final TextStyle bodySmall = TextStyle(
    fontFamily: _baseFont,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryText,
    height: 1.5,
  );

  /// Pokemon number style
  static final TextStyle pokemonNumber = TextStyle(
    fontFamily: _baseFont,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.secondaryText,
    letterSpacing: 0.5,
  );

  /// Pokemon name style
  static final TextStyle pokemonName = TextStyle(
    fontFamily: _baseFont,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryText,
    height: 1.2,
  );

  /// Pokemon type badge text
  static final TextStyle typeBadge = TextStyle(
    fontFamily: _baseFont,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    height: 1,
  );

  /// Stats label text
  static final TextStyle statsLabel = TextStyle(
    fontFamily: _baseFont,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
    height: 1.5,
  );

  /// Stats value text
  static final TextStyle statsValue = TextStyle(
    fontFamily: _baseFont,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    height: 1.5,
  );

  /// Search bar text
  static final TextStyle searchText = TextStyle(
    fontFamily: _baseFont,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.primaryText,
    height: 1.5,
  );

  /// Search placeholder text
  static final TextStyle searchPlaceholder = TextStyle(
    fontFamily: _baseFont,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.hintText,
    height: 1.5,
  );

  /// Button text
  static final TextStyle buttonText = TextStyle(
    fontFamily: _baseFont,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    height: 1.5,
  );
}
