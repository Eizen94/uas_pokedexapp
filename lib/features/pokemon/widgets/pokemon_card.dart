// lib/features/pokemon/widgets/pokemon_card.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/utils/string_helper.dart';
import '../models/pokemon_model.dart';
import 'pokemon_type_badge.dart';

/// Pokemon card component that displays Pokemon information in a visually appealing way.
/// Implements the design from the provided reference with smooth animations and proper error handling.
class PokemonCard extends StatelessWidget {
  final PokemonModel pokemon;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showStats;
  final bool isLoading;

  const PokemonCard({
    Key? key,
    required this.pokemon,
    this.onTap,
    this.isSelected = false,
    this.showStats = false,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final backgroundColor =
        AppColors.getTypeBackgroundColor(pokemon.types.first);
    final textColor = AppColors.getTextColorForBackground(backgroundColor);

    return Card(
      elevation: isSelected ? 8 : 2,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: isLoading
              ? _buildLoadingContent(textColor)
              : _buildContent(textColor),
        ),
      ),
    );
  }

  Widget _buildContent(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(textColor),
        const SizedBox(height: 16),
        _buildTypes(),
        if (showStats) ...[
          const SizedBox(height: 16),
          _buildStats(textColor),
        ],
      ],
    );
  }

  Widget _buildLoadingContent(Color textColor) {
    return Shimmer.fromColors(
      baseColor: backgroundColor.withOpacity(0.3),
      highlightColor: backgroundColor.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 60,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 60,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                StringHelper.formatPokemonId(pokemon.id),
                style: AppTextStyles.pokemonNumber.copyWith(
                  color: textColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
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
        _buildPokemonImage(textColor),
      ],
    );
  }

  Widget _buildPokemonImage(Color textColor) {
    return Hero(
      tag: 'pokemon-${pokemon.id}',
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Image.network(
            pokemon.imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.black12,
                child: Icon(
                  Icons.catching_pokemon,
                  color: textColor.withOpacity(0.5),
                  size: 32,
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTypes() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: pokemon.types.map((type) {
        return PokemonTypeBadge(
          type: type,
          small: true,
        );
      }).toList(),
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
        _buildStatBar('HP', pokemon.stats.hp, AppColors.statHp, textColor),
        const SizedBox(height: 4),
        _buildStatBar(
            'ATK', pokemon.stats.attack, AppColors.statAttack, textColor),
        const SizedBox(height: 4),
        _buildStatBar(
            'DEF', pokemon.stats.defense, AppColors.statDefense, textColor),
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
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            tween: Tween<double>(begin: 0, end: value / 255),
            builder: (context, value, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: statColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(statColor),
                  minHeight: 8,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
