// lib/features/pokemon/widgets/pokemon_card.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/utils/string_helper.dart';
import '../models/pokemon_model.dart';

/// Pokemon card widget for displaying Pokemon in grid/list views
class PokemonCard extends StatelessWidget {
  /// Pokemon data
  final PokemonModel pokemon;

  /// Card tap handler
  final VoidCallback? onTap;

  /// Favorite button tap handler
  final VoidCallback? onFavorite;

  /// Whether Pokemon is favorited
  final bool isFavorite;

  /// Constructor
  const PokemonCard({
    required this.pokemon,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    super.key,
  });

  /// Get color based on Pokemon's primary type
  Color _getTypeColor() {
    final primaryType = pokemon.types.first.toLowerCase();
    switch (primaryType) {
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

  @override
  Widget build(BuildContext context) {
    final color = _getTypeColor();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Pokemon content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pokemon image
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Hero(
                      tag: 'pokemon_${pokemon.id}',
                      child: CachedNetworkImage(
                        imageUrl: pokemon.spriteUrl,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                ),

                // Pokemon info
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        StringHelper.formatPokemonId(pokemon.id),
                        style: AppTextStyles.pokemonNumber,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        StringHelper.formatPokemonName(pokemon.name),
                        style: AppTextStyles.pokemonName,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: pokemon.types.map((type) {
                          final typeColor = _getTypeColor();
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: typeColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                type,
                                style: AppTextStyles.typeBadge,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Favorite button positioned in top right
            if (onFavorite != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                    ),
                    onPressed: onFavorite,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    iconSize: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
