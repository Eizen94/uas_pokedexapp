// lib/features/pokemon/screens/pokemon_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/pokemon_detail_model.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/error_dialog.dart';
import '../../../providers/pokemon_provider.dart';

class PokemonDetailScreen extends StatefulWidget {
  const PokemonDetailScreen({super.key});

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['id'] != null) {
      _loadPokemonDetail(args['id']);
    } else {
      _showError('Pokemon ID not provided');
    }
  }

  @override
  void dispose() {
    // Cancel any ongoing requests when leaving the screen
    if (mounted) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['id'] != null) {
        context.read<PokemonProvider>().cancelPokemonDetailRequest(args['id']);
      }
    }
    super.dispose();
  }

  Future<void> _loadPokemonDetail(int id) async {
    try {
      final provider = context.read<PokemonProvider>();
      await provider.getPokemonDetail(id);
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    }
  }

  void _showError(String message) {
    ErrorDialog.show(
      context,
      title: 'Error',
      message: message,
      onRetry: () {
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        if (args != null && args['id'] != null) {
          _loadPokemonDetail(args['id']);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PokemonProvider>(
      builder: (context, provider, child) {
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        if (args == null || args['id'] == null) {
          return const Scaffold(
            body: Center(
              child: Text('Invalid Pokemon ID'),
            ),
          );
        }

        final int pokemonId = args['id'];
        final pokemon = provider.getPokemonById(pokemonId);
        

        if (pokemon == null) {
          return const Scaffold(
            body: Center(
              child: LoadingIndicator(message: 'Loading Pokemon details...'),
            ),
          );
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    pokemon.getFormattedName(),
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: AppColors.getTypeGradient(
                                pokemon.getPrimaryType()),
                          ),
                        ),
                      ),
                      Hero(
                        tag: 'pokemon-${pokemon.id}',
                        child: CachedNetworkImage(
                          imageUrl: pokemon.imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.error,
                            size: 50,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(pokemon),
                      const SizedBox(height: 16),
                      _buildStatsSection(pokemon),
                      const SizedBox(height: 16),
                      _buildAbilitiesSection(pokemon),
                      if (pokemon.evolution != null &&
                          pokemon.evolution!.hasMultipleStages()) ...[
                        const SizedBox(height: 16),
                        _buildEvolutionSection(pokemon),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(PokemonDetailModel pokemon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pokemon.getFormattedId(),
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(
                  icon: Icons.straighten,
                  title: 'Height',
                  value: pokemon.getFormattedHeight(),
                ),
                _buildInfoItem(
                  icon: Icons.fitness_center,
                  title: 'Weight',
                  value: pokemon.getFormattedWeight(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Types',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: pokemon.types.map((type) {
                return Chip(
                  label: Text(
                    type.toUpperCase(),
                    style: AppTextStyles.pokemonType,
                  ),
                  backgroundColor: AppColors.typeColors[type.toLowerCase()],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          title,
          style: AppTextStyles.caption.copyWith(
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(PokemonDetailModel pokemon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Base Stats',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...pokemon.statsList.map((stat) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.getFormattedName(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            stat.baseStat.toString(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: stat.baseStat / 255,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                stat.getStatColor(),
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAbilitiesSection(PokemonDetailModel pokemon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Abilities',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...pokemon.abilities.map((ability) {
              return ListTile(
                title: Text(
                  ability.getFormattedName(),
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: ability.isHidden
                    ? Chip(
                        label: Text(
                          'HIDDEN',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: Colors.grey[600],
                      )
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEvolutionSection(PokemonDetailModel pokemon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pokemon.evolution?.stages.length ?? 0,
                separatorBuilder: (context, index) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(Icons.arrow_forward, color: Colors.grey),
                  );
                },
                itemBuilder: (context, index) {
                  final stage = pokemon.evolution!.stages[index];
                  return Column(
                    children: [
                      CachedNetworkImage(
                        imageUrl:
                            'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${stage.pokemonId}.png',
                        height: 80,
                        width: 80,
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                      Text(
                        stage.getFormattedName(),
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (stage.minLevel > 1)
                        Text(
                          'Level ${stage.minLevel}',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
