// lib/features/pokemon/screens/pokemon_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/pokemon_model.dart';
import '../services/pokemon_service.dart';
import '../widgets/pokemon_card.dart';

class PokemonListScreen extends StatefulWidget {
  const PokemonListScreen({Key? key}) : super(key: key);

  @override
  State<PokemonListScreen> createState() => _PokemonListScreenState();
}

class _PokemonListScreenState extends State<PokemonListScreen> {
  final PokemonService _pokemonService = PokemonService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<PokemonModel> _pokemonList = [];
  List<PokemonModel> _filteredList = [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _hasMore = true;
  bool _isInit = true;
  int _currentPage = 0;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('🔄 Initializing Pokemon List Screen');
    }
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _loadPokemon(showLoading: true);
      _isInit = false;
    }
  }

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_scrollController.position.outOfRange &&
        !_isLoading &&
        _hasMore) {
      _loadPokemon();
    }
  }

  Future<void> _loadPokemon({bool showLoading = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (showLoading) _errorMessage = '';
    });

    try {
      if (kDebugMode) {
        print('📥 Loading Pokemon page: $_currentPage');
      }

      final newPokemon = await _pokemonService.getPokemonList(
        offset: _currentPage * 20,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _pokemonList.addAll(newPokemon);
          if (!_isSearching) {
            _filteredList = List.from(_pokemonList);
          } else {
            _filterPokemon(_searchController.text);
          }
          _currentPage++;
          _hasMore = newPokemon.length == 20;
          _isLoading = false;
          _errorMessage = '';
        });
      }

      if (kDebugMode) {
        print('✅ Loaded ${newPokemon.length} Pokemon');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading Pokemon: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
        _showError(e.toString());
      }
    }
  }

  void _filterPokemon(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredList = List.from(_pokemonList);
      } else {
        _filteredList = _pokemonList
            .where((pokemon) =>
                pokemon.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _loadPokemon(showLoading: true),
        ),
      ),
    );
  }

  Future<void> _refreshPokemonList() async {
    setState(() {
      _pokemonList.clear();
      _filteredList.clear();
      _currentPage = 0;
      _hasMore = true;
      _errorMessage = '';
      _isSearching = false;
      _searchController.clear();
    });
    await _loadPokemon(showLoading: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pokedex',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPokemonList,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search Pokemon',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterPokemon('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: _filterPokemon,
                textInputAction: TextInputAction.search,
              ),
            ),
            Expanded(
              child: _buildPokemonGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPokemonGrid() {
    if (_isInit && _isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage.isNotEmpty && _pokemonList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadPokemon(showLoading: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching ? 'No Pokemon found' : 'No Pokemon available',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredList.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _filteredList.length) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return PokemonCard(
          pokemon: _filteredList[index],
          onTap: () => Navigator.pushNamed(
            context,
            '/pokemon/detail',
            arguments: {'id': _filteredList[index].id},
          ),
        );
      },
    );
  }
}
