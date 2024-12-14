// lib/features/pokemon/screens/pokemon_list_screen.dart

/// Pokemon list screen to display all Pokemon with search and filtering.
/// Main screen for browsing Pokemon collection.
library;


import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/utils/string_helper.dart';
import '../models/pokemon_model.dart';
import '../services/pokemon_service.dart';
import '../../favorites/services/favorite_service.dart';
import '../../auth/models/user_model.dart';
import 'pokemon_detail_screen.dart';

/// Get color for Pokemon type
Color _getTypeColor(String type) {
  switch (type.toLowerCase()) {
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

/// Pokemon list screen widget
class PokemonListScreen extends StatefulWidget {
  /// Current user
  final UserModel user;

  /// Constructor
  const PokemonListScreen({
    required this.user,
    super.key,
  });

  @override
  State<PokemonListScreen> createState() => _PokemonListScreenState();
}

class _PokemonListScreenState extends State<PokemonListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  late final PokemonService _pokemonService;
  late final FavoriteService _favoriteService;

  List<PokemonModel> _pokemonList = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _currentPage = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _scrollController.addListener(_scrollListener);
  }

  Future<void> _initializeServices() async {
    try {
      _pokemonService = await PokemonService.initialize();
      _favoriteService = await FavoriteService.initialize();
      if (!mounted) return;
      _loadPokemon();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to initialize services: $e';
      });
    }
  }

  Future<void> _loadPokemon() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newPokemon = await _pokemonService.getPokemonList(
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      if (!mounted) return;

      setState(() {
        _pokemonList.addAll(newPokemon);
        _currentPage++;
        _hasMore = newPokemon.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load Pokemon: $e';
        _isLoading = false;
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadPokemon();
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _pokemonList.clear();
      _currentPage = 0;
      _hasMore = true;
      _errorMessage = null;
    });
    await _loadPokemon();
  }

  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) {
      await _handleRefresh();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final searchResult = _pokemonList
          .where((pokemon) =>
              pokemon.name.toLowerCase().contains(query.toLowerCase()) ||
              '#${pokemon.id}'.contains(query))
          .toList();

      if (!mounted) return;

      setState(() {
        _pokemonList = searchResult;
        _hasMore = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Search failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(PokemonModel pokemon) async {
    try {
      await _favoriteService.addToFavorites(
        userId: widget.user.id,
        pokemon: pokemon,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${pokemon.name} to favorites'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _favoriteService.removeFromFavorites(
                userId: widget.user.id,
                favoriteId: '${widget.user.id}_${pokemon.id}',
              );
            },
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
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search Pokémon',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _handleSearch('');
                          },
                        )
                      : null,
                ),
                onChanged: _handleSearch,
              ),
            ),

            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: AppColors.error),
                ),
              ),

            // Pokemon list
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _pokemonList.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _pokemonList.length) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final pokemon = _pokemonList[index];
                    return _PokemonCard(
                      pokemon: pokemon,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PokemonDetailScreen(
                              pokemon: pokemon,
                              user: widget.user,
                            ),
                          ),
                        );
                      },
                      onFavorite: () => _toggleFavorite(pokemon),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pokemon card widget
class _PokemonCard extends StatelessWidget {
  final PokemonModel pokemon;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _PokemonCard({
    required this.pokemon,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final mainType = pokemon.types.first.toLowerCase();
    final color = _getTypeColor(mainType);

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
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.favorite_border),
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
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: pokemon.types.map((type) {
                      final typeColor = _getTypeColor(type);
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
      ),
    );
  }
}
