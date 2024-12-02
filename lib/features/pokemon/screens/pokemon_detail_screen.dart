// lib/features/pokemon/screens/pokemon_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import '../models/pokemon_detail_model.dart';
import '../services/pokemon_service.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';

class PokemonDetailScreen extends StatefulWidget {
  const PokemonDetailScreen({super.key});

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen> {
  final PokemonService _pokemonService = PokemonService();
  bool _isLoading = true;
  String _errorMessage = '';
  late PokemonDetailModel _pokemon;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['id'] != null) {
      _loadPokemonDetail(args['id'].toString());
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Pokemon ID not provided';
      });
    }
  }

  Future<void> _loadPokemonDetail(String id) async {
    try {
      if (kDebugMode) {
        print('🔄 Loading Pokemon detail: $id');
      }

      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final pokemon = await _pokemonService.getPokemonDetail(id);

      if (mounted) {
        setState(() {
          _pokemon = pokemon;
          _isLoading = false;
        });
      }

      if (kDebugMode) {
        print('✅ Pokemon detail loaded successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading Pokemon detail: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Color _getTypeColor(String type) {
    return AppColors.typeColors[type.toLowerCase()] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading Pokemon details...',
                style: AppTextStyles.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading Pokemon',
                  style: AppTextStyles.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    final args = ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                    if (args != null && args['id'] != null) {
                      _loadPokemonDetail(args['id'].toString());
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
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
                _pokemon.name.toUpperCase(),
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
                        colors: [
                          _getTypeColor(_pokemon.types.first),
                          _getTypeColor(_pokemon.types.first).withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Hero(
                    tag: 'pokemon-${_pokemon.id}',
                    child: CachedNetworkImage(
                      imageUrl: _pokemon.imageUrl,
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
                  _buildInfoCard(),
                  const SizedBox(height: 16),
                  _buildStatsSection(),
                  const SizedBox(height: 16),
                  _buildAbilitiesSection(),
                  if (_pokemon.evolution != null) ...[
                    const SizedBox(height: 16),
                    _buildEvolutionSection(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pokemon #${_pokemon.id.toString().padLeft(3, '0')}',
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
                  value: _pokemon.getFormattedHeight(),
                ),
                _buildInfoItem(
                  icon: Icons.fitness_center,
                  title: 'Weight',
                  value: _pokemon.getFormattedWeight(),
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
              children: _pokemon.types.map((type) {
                return Chip(
                  label: Text(
                    type.toUpperCase(),
                    style: AppTextStyles.pokemonType,
                  ),
                  backgroundColor: _getTypeColor(type),
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

  Widget _buildStatsSection() {
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
            ..._pokemon.statsList.map((stat) {
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
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAbilitiesSection() {
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
            ..._pokemon.abilities.map((ability) {
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
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEvolutionSection() {
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
                itemCount: _pokemon.evolution!.stages.length,
                separatorBuilder: (context, index) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(Icons.arrow_forward, color: Colors.grey),
                  );
                },
                itemBuilder: (context, index) {
                  final stage = _pokemon.evolution!.stages[index];
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
