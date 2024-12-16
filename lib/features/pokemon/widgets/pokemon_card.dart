// lib/widgets/pokemon_card.dart

/// Pokemon card widget for displaying Pokemon in grid/list views.
/// Provides consistent Pokemon representation across the app.
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/utils/string_helper.dart';
import '../models/pokemon_model.dart';
import 'pokemon_type_badge.dart';

/// Pokemon card widget
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

  /// Get background color based on Pokemon's primary type
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pokemon image
              Expanded(
                child: Stack(
                  children: [
                    Padding(
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
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                    if (onFavorite != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.grey,
                          ),
                          onPressed: onFavorite,
                        ),
                      ),
                  ],
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: pokemon.types.map((type) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: PokemonTypeBadge(
                            type: type,
                            size: BadgeSize.small,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
