// lib/widgets/evolution_chain.dart

/// Evolution chain widget to display Pokemon evolution sequences.
/// Shows evolution stages with sprites and evolution conditions.
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/constants/colors.dart';
import '../core/constants/text_styles.dart';
import '../core/utils/string_helper.dart';
import '../features/pokemon/models/pokemon_detail_model.dart';

/// Evolution chain widget
class EvolutionChain extends StatelessWidget {
  /// Evolution stages to display
  final List<EvolutionStage> evolutionChain;

  /// Constructor
  const EvolutionChain({
    required this.evolutionChain,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: evolutionChain.length,
      separatorBuilder: (context, index) => const _EvolutionArrow(),
      itemBuilder: (context, index) => _EvolutionStageItem(
        stage: evolutionChain[index],
      ),
    );
  }
}

/// Evolution stage item widget
class _EvolutionStageItem extends StatelessWidget {
  /// Evolution stage data
  final EvolutionStage stage;

  const _EvolutionStageItem({
    required this.stage,
  });

  /// Get evolution condition text
  String _getEvolutionCondition() {
    if (stage.level != null) {
      return 'Level ${stage.level}';
    } else if (stage.item != null) {
      return 'Use ${StringHelper.formatPokemonName(stage.item!)}';
    } else if (stage.trigger != null) {
      return StringHelper.formatPokemonName(stage.trigger!);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Pokemon sprite
        Hero(
          tag: 'evolution_${stage.pokemonId}',
          child: CachedNetworkImage(
            imageUrl: stage.spriteUrl,
            height: 80,
            width: 80,
            placeholder: (context, url) => const SizedBox(
              height: 80,
              width: 80,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => const SizedBox(
              height: 80,
              width: 80,
              child: Center(
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Pokemon info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                StringHelper.formatPokemonName(stage.name),
                style: AppTextStyles.heading3,
              ),
              if (_getEvolutionCondition().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _getEvolutionCondition(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Evolution arrow indicator
class _EvolutionArrow extends StatelessWidget {
  const _EvolutionArrow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 24,
            width: 2,
            decoration: BoxDecoration(
              color: AppColors.secondaryText.withOpacity(0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 16),
            child: Icon(
              Icons.arrow_downward,
              color: AppColors.secondaryText.withOpacity(0.5),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
