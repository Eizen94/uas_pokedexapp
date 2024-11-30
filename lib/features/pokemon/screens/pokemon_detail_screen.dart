// lib/features/pokemon/screens/pokemon_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import '../models/pokemon_detail_model.dart';
import '../services/pokemon_service.dart';

class PokemonDetailScreen extends StatefulWidget {
  const PokemonDetailScreen({Key? key}) : super(key: key);

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
    return switch (type.toLowerCase()) {
      'normal' => Colors.brown.shade400,
      'fire' => Colors.red,
      'water' => Colors.blue,
      'electric' => Colors.amber,
      'grass' => Colors.green,
      'ice' => Colors.cyan,
      'fighting' => Colors.orange.shade900,
      'poison' => Colors.purple,
      'ground' => Colors.brown,
      'flying' => Colors.indigo,
      'psychic' => Colors.pink,
      'bug' => Colors.lightGreen,
      'rock' => Colors.grey,
      'ghost' => Colors.deepPurple,
      'dragon' => Colors.indigo.shade900,
      'dark' => Colors.blueGrey.shade900,
      'steel' => Colors.blueGrey,
      'fairy' => Colors.pinkAccent,
      _ => Colors.grey,
    };
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
                style: Theme.of(context).textTheme.bodyLarge,
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
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
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
                style: const TextStyle(
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                  value: '${(_pokemon.height / 10).toStringAsFixed(1)}m',
                ),
                _buildInfoItem(
                  icon: Icons.fitness_center,
                  title: 'Weight',
                  value: '${(_pokemon.weight / 10).toStringAsFixed(1)}kg',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Types',
              style: TextStyle(
                fontSize: 16,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
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
            const Text(
              'Base Stats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._pokemon.stats.map((stat) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.name.toUpperCase(),
                      style: TextStyle(
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: stat.baseStat / 255,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getStatColor(stat.baseStat),
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

  Color _getStatColor(int value) {
    if (value < 50) return Colors.red;
    if (value < 100) return Colors.orange;
    if (value < 150) return Colors.green;
    return Colors.teal;
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
            const Text(
              'Abilities',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._pokemon.abilities.map((ability) {
              return ListTile(
                title: Text(
                  ability.name.replaceAll('-', ' ').toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                trailing: ability.isHidden
                    ? Chip(
                        label: const Text(
                          'HIDDEN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
            const Text(
              'Evolution Chain',
              style: TextStyle(
                fontSize: 18,
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
                        stage.name.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (stage.minLevel > 1)
                        Text(
                          'Level ${stage.minLevel}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
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
