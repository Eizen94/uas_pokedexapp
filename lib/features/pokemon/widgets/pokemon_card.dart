// lib/features/pokemon/widgets/pokemon_card.dart

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/utils/string_helper.dart';
import '../models/pokemon_model.dart';
import 'pokemon_type_badge.dart';

/// Pokemon card component that displays Pokemon information in a visually appealing way.
/// Implements the design from the provided reference with smooth animations.
class PokemonCard extends StatelessWidget {
  final PokemonModel pokemon;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showStats;

  const PokemonCard({
    Key? key,
    required this.pokemon,
    this.onTap,
    this.isSelected = false,
    this.showStats = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get background color based on Pokemon's primary type
    final backgroundColor =
        AppColors.getTypeBackgroundColor(pokemon.types.first);
    final textColor = AppColors.getTextColorForBackground(backgroundColor);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Card(
        elevation: isSelected ? 8 : 2,
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pokemon ID and Name Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pokemon Number
                          Text(
                            StringHelper.formatPokemonId(pokemon.id),
                            style: AppTextStyles.pokemonNumber.copyWith(
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Pokemon Name
                          Text(
                            StringHelper.formatPokemonName(pokemon.name),
                            style: AppTextStyles.pokemonName.copyWith(
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Pokemon Image
                    Hero(
                      tag: 'pokemon-${pokemon.id}',
                      child: Image.network(
                        pokemon.imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.black12,
                            child: Icon(
                              Icons.broken_image,
                              color: textColor.withOpacity(0.5),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Pokemon Types
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pokemon.types.map((type) {
                    return PokemonTypeBadge(
                      type: type,
                      small: true,
                    );
                  }).toList(),
                ),
                // Stats Section (if enabled)
                if (showStats) ...[
                  const SizedBox(height: 16),
                  _buildStats(textColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStats(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Base Stats',
          style: AppTextStyles.bodyMedium.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // HP
        _buildStatBar(
          'HP',
          pokemon.stats.hp,
          AppColors.statHp,
          textColor,
        ),
        const SizedBox(height: 4),
        // Attack
        _buildStatBar(
          'ATK',
          pokemon.stats.attack,
          AppColors.statAttack,
          textColor,
        ),
        const SizedBox(height: 4),
        // Defense
        _buildStatBar(
          'DEF',
          pokemon.stats.defense,
          AppColors.statDefense,
          textColor,
        ),
      ],
    );
  }

  Widget _buildStatBar(
    String label,
    int value,
    Color statColor,
    Color textColor,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: textColor.withOpacity(0.7),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            value.toString(),
            style: AppTextStyles.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 255, // Max stat value
              backgroundColor: statColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(statColor),
              minHeight: 8,
            ),
          ),
        ),
      ],
    );
  }
}
