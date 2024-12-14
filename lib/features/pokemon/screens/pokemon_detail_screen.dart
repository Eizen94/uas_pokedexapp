// lib/features/pokemon/screens/pokemon_detail_screen.dart

/// Pokemon detail screen to display detailed Pokemon information.
/// Shows complete Pokemon data, stats, evolution chain, and moves.
library;


import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/utils/string_helper.dart';
import '../models/pokemon_model.dart';
import '../models/pokemon_detail_model.dart';
import '../services/pokemon_service.dart';
import '../../favorites/services/favorite_service.dart';
import '../../auth/models/user_model.dart';

/// Get color for Pokemon type
Color _getTypeColor(String type) {
  switch (type.toLowerCase()) {
    case 'bug': return PokemonTypeColors.bug;
    case 'dark': return PokemonTypeColors.dark;
    case 'dragon': return PokemonTypeColors.dragon;
    case 'electric': return PokemonTypeColors.electric;
    case 'fairy': return PokemonTypeColors.fairy;
    case 'fighting': return PokemonTypeColors.fighting;
    case 'fire': return PokemonTypeColors.fire;
    case 'flying': return PokemonTypeColors.flying;
    case 'ghost': return PokemonTypeColors.ghost;
    case 'grass': return PokemonTypeColors.grass;
    case 'ground': return PokemonTypeColors.ground;
    case 'ice': return PokemonTypeColors.ice;
    case 'normal': return PokemonTypeColors.normal;
    case 'poison': return PokemonTypeColors.poison;
    case 'psychic': return PokemonTypeColors.psychic;
    case 'rock': return PokemonTypeColors.rock;
    case 'steel': return PokemonTypeColors.steel;
    case 'water': return PokemonTypeColors.water;
    default: return PokemonTypeColors.normal;
  }
}

/// Pokemon detail screen widget
class PokemonDetailScreen extends StatefulWidget {
  /// Basic Pokemon data
  final PokemonModel pokemon;

  /// Current user
  final UserModel user;

  /// Constructor
  const PokemonDetailScreen({
    required this.pokemon,
    required this.user,
    super.key,
  });

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final PokemonService _pokemonService;
  late final FavoriteService _favoriteService;

  PokemonDetailModel? _pokemonDetail;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _pokemonService = await PokemonService.initialize();
      _favoriteService = await FavoriteService.initialize();
      if (!mounted) return;
      await _loadPokemonDetail();
      await _checkFavoriteStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPokemonDetail() async {
    try {
      final detail = await _pokemonService.getPokemonDetail(widget.pokemon.id);
      if (!mounted) return;
      setState(() {
        _pokemonDetail = detail;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkFavoriteStatus() async {
    try {
      final favorite = await _favoriteService.getFavorite(
        userId: widget.user.id,
        favoriteId: '${widget.user.id}_${widget.pokemon.id}',
      );
      if (!mounted) return;
      setState(() {
        _isFavorite = favorite != null;
      });
    } catch (e) {
      // Silently fail favorite check
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      if (_isFavorite) {
        await _favoriteService.removeFromFavorites(
          userId: widget.user.id,
          favoriteId: '${widget.user.id}_${widget.pokemon.id}',
        );
      } else {
        await _favoriteService.addToFavorites(
          userId: widget.user.id,
          pokemon: widget.pokemon,
        );
      }
      
      if (!mounted) return;
      
      setState(() {
        _isFavorite = !_isFavorite;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite 
                ? 'Added ${widget.pokemon.name} to favorites'
                : 'Removed ${widget.pokemon.name} from favorites',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mainType = widget.pokemon.types.first.toLowerCase();
    final color = _getTypeColor(mainType);

    return Scaffold(
      backgroundColor: color,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: Colors.white,
                    ),
                    onPressed: _toggleFavorite,
                  ),
                ],
              ),
            ),

            // Pokemon header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            StringHelper.formatPokemonName(widget.pokemon.name),
                            style: AppTextStyles.heading1.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: widget.pokemon.types.map((type) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
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
                      Text(
                        StringHelper.formatPokemonId(widget.pokemon.id),
                        style: AppTextStyles.pokemonNumber.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Hero(
                    tag: 'pokemon_${widget.pokemon.id}',
                    child: CachedNetworkImage(
                      imageUrl: widget.pokemon.spriteUrl,
                      height: 200,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Content area
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    // Tab bar
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primaryText,
                      unselectedLabelColor: AppColors.secondaryText,
                      tabs: const [
                        Tab(text: 'About'),
                        Tab(text: 'Stats'),
                        Tab(text: 'Evolution'),
                      ],
                    ),

                    // Tab content
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _errorMessage != null
                              ? Center(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                )
                              : TabBarView(
                                  controller: _tabController,
                                  children: [
                                    _AboutTab(pokemonDetail: _pokemonDetail!),
                                    _StatsTab(pokemonDetail: _pokemonDetail!),
                                    _EvolutionTab(pokemonDetail: _pokemonDetail!),
                                  ],
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// About tab content
class _AboutTab extends StatelessWidget {
  final PokemonDetailModel pokemonDetail;

  const _AboutTab({required this.pokemonDetail});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pokemonDetail.description),
          const SizedBox(height: 24),
          _InfoRow('Height', StringHelper.formatHeight(pokemonDetail.height)),
          _InfoRow('Weight', StringHelper.formatWeight(pokemonDetail.weight)),
          _InfoRow('Species', pokemonDetail.species),
          _InfoRow('Habitat', pokemonDetail.habitat),
          _InfoRow('Gender Ratio', '${pokemonDetail.genderRatio}% Female'),
          _InfoRow('Catch Rate', '${pokemonDetail.catchRate}%'),
          const SizedBox(height: 24),
          Text('Abilities', style: AppTextStyles.heading3),
          const SizedBox(height: 16),
          ...pokemonDetail.abilities.map((ability) => _AbilityItem(ability)),
        ],
      ),
    );
  }
}

/// Stats tab content
class _StatsTab extends StatelessWidget {
  final PokemonDetailModel pokemonDetail;

  const _StatsTab({required this.pokemonDetail});

  @override
  Widget build(BuildContext context) {
    final stats = pokemonDetail.stats;
    final maxStat = 255.0; // Maximum possible base stat

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _StatBar('HP', stats.hp, maxStat, StatColors.hp),
          _StatBar('Attack', stats.attack, maxStat, StatColors.attack),
          _StatBar('Defense', stats.defense, maxStat, StatColors.defense),
          _StatBar('Sp. Attack', stats.specialAttack, maxStat, StatColors.specialAttack),
          _StatBar('Sp. Defense', stats.specialDefense, maxStat, StatColors.specialDefense),
          _StatBar('Speed', stats.speed, maxStat, StatColors.speed),
          const SizedBox(height: 24),
          _StatBar('Total', stats.total.toDouble(), maxStat * 6, StatColors.total),
        ],
      ),
    );
  }
}

/// Evolution tab content
class _EvolutionTab extends StatelessWidget {
  final PokemonDetailModel pokemonDetail;

  const _EvolutionTab({required this.pokemonDetail});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: pokemonDetail.evolutionChain.length,
      separatorBuilder: (context, index) => const _EvolutionArrow(),
      itemBuilder: (context, index) {
        final evolution = pokemonDetail.evolutionChain[index];
        return _EvolutionItem(evolution);
      },
    );
  }
}

/// Helper widgets
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbilityItem extends StatelessWidget {
  final PokemonAbility ability;

  const _AbilityItem(this.ability);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                ability.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              if (ability.isHidden)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryText.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                     'Hidden',
                     style: TextStyle(
                       fontSize: 12,
                       color: AppColors.secondaryText,
                       fontWeight: FontWeight.w500,
                     ),
                   ),
                 ),
             ),
           ],
         ),
         const SizedBox(height: 4),
         Text(
           ability.description,
           style: TextStyle(
             color: AppColors.secondaryText,
           ),
         ),
       ],
     ),
   );
 }
}

class _StatBar extends StatelessWidget {
 final String label;
 final double value;
 final double maxValue;
 final Color color;

 const _StatBar(this.label, this.value, this.maxValue, this.color);

 @override
 Widget build(BuildContext context) {
   return Padding(
     padding: const EdgeInsets.symmetric(vertical: 8),
     child: Column(
       children: [
         Row(
           children: [
             SizedBox(
               width: 100,
               child: Text(
                 label,
                 style: TextStyle(
                   color: AppColors.secondaryText,
                   fontWeight: FontWeight.w500,
                 ),
               ),
             ),
             const SizedBox(width: 8),
             Text(
               value.toInt().toString(),
               style: const TextStyle(
                 color: AppColors.primaryText,
                 fontWeight: FontWeight.w600,
               ),
             ),
             const SizedBox(width: 8),
             Expanded(
               child: ClipRRect(
                 borderRadius: BorderRadius.circular(4),
                 child: LinearProgressIndicator(
                   value: value / maxValue,
                   backgroundColor: color.withOpacity(0.2),
                   valueColor: AlwaysStoppedAnimation<Color>(color),
                   minHeight: 8,
                 ),
               ),
             ),
           ],
         ),
       ],
     ),
   );
 }
}

class _EvolutionItem extends StatelessWidget {
 final EvolutionStage evolution;

 const _EvolutionItem(this.evolution);

 @override
 Widget build(BuildContext context) {
   return Row(
     children: [
       CachedNetworkImage(
         imageUrl: evolution.spriteUrl,
         height: 80,
         width: 80,
         placeholder: (context, url) => const SizedBox(
           height: 80,
           width: 80,
           child: Center(child: CircularProgressIndicator()),
         ),
         errorWidget: (context, url, error) => const SizedBox(
           height: 80,
           width: 80,
           child: Icon(Icons.error_outline),
         ),
       ),
       const SizedBox(width: 16),
       Expanded(
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(
               StringHelper.formatPokemonName(evolution.name),
               style: AppTextStyles.pokemonName,
             ),
             if (evolution.level != null)
               Text(
                 'Level ${evolution.level}',
                 style: TextStyle(color: AppColors.secondaryText),
               ),
             if (evolution.item != null)
               Text(
                 'Use ${evolution.item}',
                 style: TextStyle(color: AppColors.secondaryText),
               ),
           ],
         ),
       ),
     ],
   );
 }
}

class _EvolutionArrow extends StatelessWidget {
 const _EvolutionArrow();

 @override
 Widget build(BuildContext context) {
   return const Padding(
     padding: EdgeInsets.symmetric(vertical: 8),
     child: Icon(
       Icons.arrow_downward,
       color: AppColors.secondaryText,
     ),
   );
 }
}