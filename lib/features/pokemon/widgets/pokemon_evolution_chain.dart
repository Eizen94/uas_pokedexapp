// lib/features/pokemon/widgets/pokemon_evolution_chain.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../models/pokemon_detail_model.dart';

class PokemonEvolutionChain extends StatelessWidget {
  final Evolution evolution;
  final void Function(int pokemonId)? onPokemonTap;

  const PokemonEvolutionChain({
    super.key,
    required this.evolution,
    this.onPokemonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evolution Chain',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildEvolutionChain(),
          ],
        ),
      ),
    );
  }

  Widget _buildEvolutionChain() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(evolution.stages.length * 2 - 1, (index) {
          // Even indices are Pokemon stages, odd indices are arrows
          if (index.isEven) {
            final stageIndex = index ~/ 2;
            return _buildEvolutionStage(evolution.stages[stageIndex]);
          } else {
            final nextStageIndex = (index + 1) ~/ 2;
            return _buildEvolutionArrow(evolution.stages[nextStageIndex]);
          }
        }),
      ),
    );
  }

  Widget _buildEvolutionStage(EvolutionStage stage) {
    return GestureDetector(
      onTap: () => onPokemonTap?.call(stage.pokemonId),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'evolution-${stage.pokemonId}',
              child: CachedNetworkImage(
                imageUrl:
                    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${stage.pokemonId}.png',
                height: 80,
                width: 80,
                placeholder: (context, url) => const SizedBox(
                  height: 80,
                  width: 80,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              stage.getFormattedName(),
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (stage.minLevel > 1)
              Text(
                'Level ${stage.minLevel}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvolutionArrow(EvolutionStage nextStage) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.arrow_forward,
            color: AppColors.textSecondaryLight,
          ),
          if (nextStage.minLevel > 1)
            Text(
              'Lv.${nextStage.minLevel}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
        ],
      ),
    );
  }

  // Helper method untuk custom evolution trigger
  Widget _buildEvolutionTrigger(String trigger) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        trigger,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Example usage:
///```dart
/// PokemonEvolutionChain(
///   evolution: pokemonDetail.evolution!,
///   onPokemonTap: (pokemonId) {
///     // Navigate to pokemon detail
///     Navigator.pushNamed(
///       context,
///       '/pokemon/detail',
///       arguments: {'id': pokemonId},
///     );
///   },
/// )
///```