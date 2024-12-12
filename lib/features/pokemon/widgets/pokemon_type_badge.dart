// lib/features/pokemon/widgets/pokemon_type_badge.dart

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/utils/string_helper.dart';

/// Pokemon type badge component that displays the Pokemon's type
/// with proper styling and animations based on the design reference.
class PokemonTypeBadge extends StatelessWidget {
  final String type;
  final bool small;
  final VoidCallback? onTap;
  final bool isAnimated;

  const PokemonTypeBadge({
    Key? key,
    required this.type,
    this.small = false,
    this.onTap,
    this.isAnimated = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return isAnimated
        ? _buildAnimatedBadge(context)
        : _buildStaticBadge(context);
  }

  Widget _buildAnimatedBadge(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      tween: Tween<double>(begin: 0.8, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: _buildStaticBadge(context),
        );
      },
    );
  }

  Widget _buildStaticBadge(BuildContext context) {
    final typeColor = AppColors.getTypeColor(type);
    final textColor = Colors.white; // Type badges always use white text
    final gradientColors = AppColors.getTypeGradient(type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(small ? 8 : 12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(small ? 8 : 12),
            boxShadow: [
              BoxShadow(
                color: typeColor.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: small ? 8 : 12,
              vertical: small ? 4 : 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypeIcon(type),
                if (!small) const SizedBox(width: 4),
                Text(
                  StringHelper.formatTypeName(type),
                  style: (small
                          ? AppTextStyles.caption
                          : AppTextStyles.pokemonType)
                      .copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(String type) {
    // Use custom icons based on Pokemon type
    IconData getTypeIcon() {
      switch (type.toLowerCase()) {
        case 'bug':
          return Icons.bug_report;
        case 'dark':
          return Icons.nights_stay;
        case 'dragon':
          return Icons.auto_fix_high;
        case 'electric':
          return Icons.flash_on;
        case 'fairy':
          return Icons.star;
        case 'fighting':
          return Icons.sports_kabaddi;
        case 'fire':
          return Icons.local_fire_department;
        case 'flying':
          return Icons.air;
        case 'ghost':
          return Icons.blur_on;
        case 'grass':
          return Icons.eco;
        case 'ground':
          return Icons.landscape;
        case 'ice':
          return Icons.ac_unit;
        case 'normal':
          return Icons.circle_outlined;
        case 'poison':
          return Icons.science;
        case 'psychic':
          return Icons.psychology;
        case 'rock':
          return Icons.terrain;
        case 'steel':
          return Icons.shield;
        case 'water':
          return Icons.water_drop;
        default:
          return Icons.catching_pokemon;
      }
    }

    if (small) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(
        getTypeIcon(),
        color: Colors.white,
        size: small ? 12 : 16,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }
}
