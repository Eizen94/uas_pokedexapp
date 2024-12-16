// lib/widgets/pokemon_type_badge.dart

/// Pokemon type badge widget to display Pokemon types.
/// Used across the app for consistent type representation.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';

/// Pokemon type badge widget
class PokemonTypeBadge extends StatelessWidget {
  /// Pokemon type to display
  final String type;

  /// Optional badge size
  final BadgeSize size;

  /// Optional explicit width
  final double? width;

  /// Constructor
  const PokemonTypeBadge({
    required this.type,
    this.size = BadgeSize.medium,
    this.width,
    super.key,
  });

  /// Get background color based on type
  Color _getTypeColor(String pokemonType) {
    switch (pokemonType.toLowerCase()) {
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

  /// Get padding based on size
  EdgeInsets _getPadding() {
    switch (size) {
      case BadgeSize.small:
        return const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        );
      case BadgeSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        );
      case BadgeSize.large:
        return const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        );
    }
  }

  /// Get font size based on size
  double _getFontSize() {
    switch (size) {
      case BadgeSize.small:
        return 10;
      case BadgeSize.medium:
        return 12;
      case BadgeSize.large:
        return 14;
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getTypeColor(type);

    return Container(
      width: width,
      padding: _getPadding(),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        type.toUpperCase(),
        style: AppTextStyles.typeBadge.copyWith(
          fontSize: _getFontSize(),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Badge size options
enum BadgeSize {
  /// Small badge (icons list)
  small,

  /// Medium badge (card view)
  medium,

  /// Large badge (detail view)
  large,
}
