// lib/features/pokemon/screens/pokemon_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../widgets/pokemon_card.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/error_dialog.dart';
import '../../../providers/pokemon_provider.dart';

class PokemonListScreen extends StatefulWidget {
  const PokemonListScreen({super.key});

  @override
  State<PokemonListScreen> createState() => _PokemonListScreenState();
}

class _PokemonListScreenState extends State<PokemonListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _initializePokemonList();
  }

  @override
  void dispose() {
    // Cancel any ongoing requests
    context.read<PokemonProvider>().cancelAllRequests();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializePokemonList() async {
    await context.read<PokemonProvider>().initializePokemonList();
  }

  void _scrollListener() {
    final provider = context.read<PokemonProvider>();
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_scrollController.position.outOfRange &&
        !provider.isLoading &&
        provider.hasMore) {
      provider.loadPokemon();
    }
  }

  Future<void> _refreshPokemonList() async {
    await context.read<PokemonProvider>().refreshPokemonList();
  }

  void _showError(String message) {
    ErrorDialog.show(
      context,
      title: 'Error',
      message: message,
      onRetry: () => _refreshPokemonList(),
    );
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
      body: Consumer<PokemonProvider>(
        builder: (context, provider, child) {
          if (provider.hasError) {
            _showError(provider.error);
          }

          return RefreshIndicator(
            onRefresh: _refreshPokemonList,
            child: Column(
              children: [
                _buildSearchBar(provider),
                Expanded(
                  child: _buildPokemonGrid(provider),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(PokemonProvider provider) {
    return Container(
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
                    provider.searchPokemon('');
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
        onChanged: provider.searchPokemon,
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildPokemonGrid(PokemonProvider provider) {
    if (provider.isLoading && provider.pokemonList.isEmpty) {
      return const Center(
        child: LoadingIndicator(message: 'Loading Pokemon...'),
      );
    }

    if (provider.pokemonList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              provider.searchQuery.isEmpty
                  ? Icons.catching_pokemon
                  : Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              provider.searchQuery.isEmpty
                  ? 'No Pokemon available'
                  : 'No Pokemon found',
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
      itemCount: provider.pokemonList.length + (provider.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= provider.pokemonList.length) {
          return const Center(
            child: LoadingIndicator(
              size: 32,
              message: 'Loading more...',
            ),
          );
        }

        final pokemon = provider.pokemonList[index];
        return PokemonCard(
          pokemon: pokemon,
          onTap: () => Navigator.pushNamed(
            context,
            '/pokemon/detail',
            arguments: {'id': pokemon.id},
          ),
        );
      },
    );
  }
}
