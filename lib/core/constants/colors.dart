// lib/core/constants/colors.dart

/// Core color constants for the Pokedex application.
/// Contains all color definitions used throughout the app for consistent theming.
library core.constants.colors;

import 'package:flutter/material.dart';

/// Core application colors used across all screens and components
class AppColors {
  const AppColors._();

  /// Primary app background color
  static const Color background = Color(0xFFF5F5F5);

  /// Secondary background for cards
  static const Color cardBackground = Colors.white;

  /// Primary text color for headings and important text
  static const Color primaryText = Color(0xFF1A1A1A);

  /// Secondary text color for descriptions and subtitles
  static const Color secondaryText = Color(0xFF666666);

  /// Hint text color for search and inputs
  static const Color hintText = Color(0xFF999999);

  /// Search bar background color
  static const Color searchBackground = Color(0xFFF2F2F2);

  /// Primary button color
  static const Color primaryButton = Color(0xFFE3350D);

  /// Secondary button color
  static const Color secondaryButton = Color(0xFFF5F5F5);

  /// Disabled button/text color
  static const Color disabled = Color(0xFFCCCCCC);

  /// Error color for warnings and errors
  static const Color error = Color(0xFFE3350D);

  /// Success color for confirmations
  static const Color success = Color(0xFF5FBD58);

  /// Card border color
  static const Color cardBorder = Color(0xFFE8E8E8);

  /// Card shadow color
  static const Color cardShadow = Color(0x1A000000);

  /// Divider color
  static const Color divider = Color(0xFFE8E8E8);

  /// Overlay color for modals
  static const Color overlay = Color(0x80000000);
}

/// Pokemon type-specific colors for type badges and backgrounds
class PokemonTypeColors {
  const PokemonTypeColors._();

  /// Bug type color
  static const Color bug = Color(0xFF92BC2C);
  static const Color bugLight = Color(0xFFAED364);

  /// Dark type color
  static const Color dark = Color(0xFF595761);
  static const Color darkLight = Color(0xFF757785);

  /// Dragon type color
  static const Color dragon = Color(0xFF0C69C8);
  static const Color dragonLight = Color(0xFF2D8BE0);

  /// Electric type color
  static const Color electric = Color(0xFFF2D94E);
  static const Color electricLight = Color(0xFFF6E579);

  /// Fairy type color
  static const Color fairy = Color(0xFFEE90E6);
  static const Color fairyLight = Color(0xFFF4B5EF);

  /// Fighting type color
  static const Color fighting = Color(0xFFD3425F);
  static const Color fightingLight = Color(0xFFE46379);

  /// Fire type color
  static const Color fire = Color(0xFFFBA54C);
  static const Color fireLight = Color(0xFFFDBC71);

  /// Flying type color
  static const Color flying = Color(0xFFA1BBEC);
  static const Color flyingLight = Color(0xFFBFD2F2);

  /// Ghost type color
  static const Color ghost = Color(0xFF5F6DBC);
  static const Color ghostLight = Color(0xFF7B87CF);

  /// Grass type color
  static const Color grass = Color(0xFF5FBD58);
  static const Color grassLight = Color(0xFF7FCF78);

  /// Ground type color
  static const Color ground = Color(0xFFDA7C4D);
  static const Color groundLight = Color(0xFFE4986E);

  /// Ice type color
  static const Color ice = Color(0xFF75D0C1);
  static const Color iceLight = Color(0xFF96DFCF);

  /// Normal type color
  static const Color normal = Color(0xFFA0A29F);
  static const Color normalLight = Color(0xFFB8BAB7);

  /// Poison type color
  static const Color poison = Color(0xFFB763CF);
  static const Color poisonLight = Color(0xFFC783DD);

  /// Psychic type color
  static const Color psychic = Color(0xFFFA8581);
  static const Color psychicLight = Color(0xFFFCA29F);

  /// Rock type color
  static const Color rock = Color(0xFFC9BB8A);
  static const Color rockLight = Color(0xFFD7CCA6);

  /// Steel type color
  static const Color steel = Color(0xFF5695A3);
  static const Color steelLight = Color(0xFF73AAB7);

  /// Water type color
  static const Color water = Color(0xFF539DDF);
  static const Color waterLight = Color(0xFF75B3E7);
}

/// Pokemon stat colors for visualization in stats charts
class StatColors {
  const StatColors._();

  /// HP stat color and gradient
  static const Color hp = Color(0xFFFF0000);
  static const Color hpLight = Color(0xFFFF5959);

  /// Attack stat color and gradient
  static const Color attack = Color(0xFFF08030);
  static const Color attackLight = Color(0xFFF4A165);

  /// Defense stat color and gradient
  static const Color defense = Color(0xFFF8D030);
  static const Color defenseLight = Color(0xFFFADD65);

  /// Special Attack stat color and gradient
  static const Color specialAttack = Color(0xFF6890F0);
  static const Color specialAttackLight = Color(0xFF8CADFF);

  /// Special Defense stat color and gradient
  static const Color specialDefense = Color(0xFF78C850);
  static const Color specialDefenseLight = Color(0xFF97DB74);

  /// Speed stat color and gradient
  static const Color speed = Color(0xFFF85888);
  static const Color speedLight = Color(0xFFFA7CA3);

  /// Total stats color and gradient
  static const Color total = Color(0xFF7C7C7C);
  static const Color totalLight = Color(0xFF9E9E9E);
}

/// Colors for generation badges and cards
class GenerationColors {
  const GenerationColors._();

  /// Generation I (Red & Green/Blue)
  static const Color gen1 = Color(0xFFFF1111);

  /// Generation II (Gold & Silver)
  static const Color gen2 = Color(0xFFFF9900);

  /// Generation III (Ruby & Sapphire)
  static const Color gen3 = Color(0xFF3366FF);

  /// Generation IV (Diamond & Pearl)
  static const Color gen4 = Color(0xFF33CC33);

  /// Generation V (Black & White)
  static const Color gen5 = Color(0xFF9933FF);

  /// Generation VI (X & Y)
  static const Color gen6 = Color(0xFFFF3399);

  /// Generation VII (Sun & Moon)
  static const Color gen7 = Color(0xFF00CCFF);

  /// Generation VIII (Sword & Shield)
  static const Color gen8 = Color(0xFFFF99CC);

  /// Generation IX (Scarlet & Violet)
  static const Color gen9 = Color(0xFF9B4D9F);
}
