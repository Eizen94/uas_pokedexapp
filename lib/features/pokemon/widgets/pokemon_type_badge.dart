// lib/features/pokemon/widgets/pokemon_type_badge.dart

import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';

class PokemonTypeBadge extends StatelessWidget {
  final String type;
  final double? width;
  final double? height;
  final double? fontSize;
  final bool showIcon;
  final VoidCallback? onTap;

  const PokemonTypeBadge({
    super.key,
    required this.type,
    this.width,
    this.height,
    this.fontSize,
    this.showIcon = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: _getTypeColor(),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _getTypeColor().withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showIcon) ...[
              _buildTypeIcon(),
              const SizedBox(width: 4),
            ],
            Text(
              _formatTypeName(),
              style: (fontSize != null
                      ? AppTextStyles.pokemonType.copyWith(fontSize: fontSize)
                      : AppTextStyles.pokemonType)
                  .copyWith(
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.25),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: _getTypeIcon(),
      ),
    );
  }

  String _formatTypeName() {
    return type.substring(0, 1).toUpperCase() + type.substring(1).toLowerCase();
  }

  Color _getTypeColor() {
    return AppColors.typeColors[type.toLowerCase()] ??
        AppColors.typeColors['normal']!;
  }

  Widget _getTypeIcon() {
    switch (type.toLowerCase()) {
      case 'normal':
        return const Icon(Icons.radio_button_unchecked,
            size: 14, color: Colors.white);
      case 'fire':
        return const Icon(Icons.local_fire_department,
            size: 14, color: Colors.white);
      case 'water':
        return const Icon(Icons.water_drop, size: 14, color: Colors.white);
      case 'electric':
        return const Icon(Icons.electric_bolt, size: 14, color: Colors.white);
      case 'grass':
        return const Icon(Icons.eco, size: 14, color: Colors.white);
      case 'ice':
        return const Icon(Icons.ac_unit, size: 14, color: Colors.white);
      case 'fighting':
        return const Icon(Icons.fitness_center, size: 14, color: Colors.white);
      case 'poison':
        return const Icon(Icons.science, size: 14, color: Colors.white);
      case 'ground':
        return const Icon(Icons.landscape, size: 14, color: Colors.white);
      case 'flying':
        return const Icon(Icons.air, size: 14, color: Colors.white);
      case 'psychic':
        return const Icon(Icons.psychology, size: 14, color: Colors.white);
      case 'bug':
        return const Icon(Icons.bug_report, size: 14, color: Colors.white);
      case 'rock':
        return const Icon(Icons.terrain, size: 14, color: Colors.white);
      case 'ghost':
        return const Icon(Icons.blur_on, size: 14, color: Colors.white);
      case 'dragon':
        return const Icon(Icons.auto_fix_high, size: 14, color: Colors.white);
      case 'dark':
        return const Icon(Icons.dark_mode, size: 14, color: Colors.white);
      case 'steel':
        return const Icon(Icons.settings, size: 14, color: Colors.white);
      case 'fairy':
        return const Icon(Icons.auto_awesome, size: 14, color: Colors.white);
      default:
        return const Icon(Icons.help_outline, size: 14, color: Colors.white);
    }
  }

  // Factory constructors for different sizes
  factory PokemonTypeBadge.small({
    required String type,
    VoidCallback? onTap,
  }) {
    return PokemonTypeBadge(
      type: type,
      height: 24,
      fontSize: 12,
      showIcon: false,
      onTap: onTap,
    );
  }

  factory PokemonTypeBadge.medium({
    required String type,
    VoidCallback? onTap,
  }) {
    return PokemonTypeBadge(
      type: type,
      height: 32,
      fontSize: 14,
      onTap: onTap,
    );
  }

  factory PokemonTypeBadge.large({
    required String type,
    VoidCallback? onTap,
  }) {
    return PokemonTypeBadge(
      type: type,
      height: 40,
      fontSize: 16,
      onTap: onTap,
    );
  }
}

class PokemonTypeBadgeGroup extends StatelessWidget {
  final List<String> types;
  final double spacing;
  final bool showIcons;
  final void Function(String)? onTypeTap;

  const PokemonTypeBadgeGroup({
    super.key,
    required this.types,
    this.spacing = 8,
    this.showIcons = true,
    this.onTypeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: types.map((type) {
        return PokemonTypeBadge(
          type: type,
          showIcon: showIcons,
          onTap: onTypeTap != null ? () => onTypeTap!(type) : null,
        );
      }).toList(),
    );
  }
}
