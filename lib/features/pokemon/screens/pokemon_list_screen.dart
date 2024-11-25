import 'package:flutter/material.dart';
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
  bool _hasMore = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadPokemon();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange &&
        !_isLoading &&
        _hasMore) {
      _loadPokemon();
    }
  }

  Future<void> _loadPokemon() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final newPokemon = await _pokemonService.getPokemonList(
        offset: _currentPage * 20,
        limit: 20,
      );

      setState(() {
        _pokemonList.addAll(newPokemon);
        _filteredList = List.from(_pokemonList);
        _currentPage++;
        _hasMore = newPokemon.length == 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load Pokemon: $e');
    }
  }

  void _filterPokemon(String query) {
    setState(() {
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
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokedex'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Pokemon',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
              ),
              onChanged: _filterPokemon,
            ),
          ),
          Expanded(
            child: _filteredList.isEmpty && !_isLoading
                ? const Center(
                    child: Text('No Pokemon found'),
                  )
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _filteredList.length + (_isLoading ? 1 : 0),
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
                          arguments: _filteredList[index],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
