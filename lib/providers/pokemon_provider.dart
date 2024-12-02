// lib/providers/pokemon_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../features/pokemon/models/pokemon_model.dart';
import '../features/pokemon/models/pokemon_detail_model.dart';
import '../features/pokemon/services/pokemon_service.dart';

class PokemonProvider extends ChangeNotifier {
  final PokemonService _pokemonService = PokemonService();

  List<PokemonModel> _pokemonList = [];
  List<PokemonModel> _filteredList = [];
  Map<int, PokemonDetailModel> _pokemonDetails = {};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _error = '';
  int _currentPage = 0;
  String _searchQuery = '';

  // Getters
  List<PokemonModel> get pokemonList => _filteredList;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String get error => _error;
  bool get hasError => _error.isNotEmpty;
  String get searchQuery => _searchQuery;

  // Initialize
  Future<void> initializePokemonList() async {
    if (_pokemonList.isNotEmpty) return;
    await loadPokemon(showLoading: true);
  }

  // Load Pokemon List
  Future<void> loadPokemon({bool showLoading = false}) async {
    if (_isLoading || (_isLoadingMore && !showLoading)) return;

    try {
      if (showLoading) {
        _setLoading(true);
        _error = '';
      } else {
        _isLoadingMore = true;
      }
      notifyListeners();

      final newPokemon = await _pokemonService.getPokemonList(
        offset: _currentPage * 20,
        limit: 20,
      );

      if (!showLoading && _pokemonList.isEmpty) {
        _setLoading(false);
        return;
      }

      _pokemonList.addAll(newPokemon);
      _filterPokemon(_searchQuery);
      _currentPage++;
      _hasMore = newPokemon.length == 20;
      _error = '';
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error loading Pokemon: $_error');
      }
    } finally {
      _setLoading(false);
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Load Pokemon Detail
  Future<PokemonDetailModel?> getPokemonDetail(int id) async {
    try {
      if (_pokemonDetails.containsKey(id)) {
        return _pokemonDetails[id];
      }

      final detail = await _pokemonService.getPokemonDetail(id.toString());
      _pokemonDetails[id] = detail;
      return detail;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('Error loading Pokemon detail: $_error');
      }
      return null;
    }
  }

  // Search/Filter Pokemon
  void searchPokemon(String query) {
    _searchQuery = query.toLowerCase();
    _filterPokemon(_searchQuery);
    notifyListeners();
  }

  void _filterPokemon(String query) {
    if (query.isEmpty) {
      _filteredList = List.from(_pokemonList);
    } else {
      _filteredList = _pokemonList
          .where((pokemon) =>
              pokemon.name.toLowerCase().contains(query) ||
              pokemon.id.toString() == query ||
              pokemon.types.any((type) => type.toLowerCase().contains(query)))
          .toList();
    }
  }

  // Refresh Pokemon List
  Future<void> refreshPokemonList() async {
    _pokemonList.clear();
    _filteredList.clear();
    _pokemonDetails.clear();
    _currentPage = 0;
    _hasMore = true;
    _error = '';
    _searchQuery = '';
    notifyListeners();
    await loadPokemon(showLoading: true);
  }

  // Clear Pokemon Details Cache
  void clearPokemonDetailsCache() {
    _pokemonDetails.clear();
    notifyListeners();
  }

  // Helper Methods
  void _setLoading(bool value) {
    _isLoading = value;
    if (!value) {
      _isLoadingMore = false;
    }
  }

  // Error Handling
  void clearError() {
    _error = '';
    notifyListeners();
  }

  // Stats and Type Helpers
  List<PokemonModel> getPokemonByType(String type) {
    return _pokemonList
        .where((pokemon) => pokemon.types.contains(type.toLowerCase()))
        .toList();
  }

  Map<String, int> getTypeDistribution() {
    final Map<String, int> distribution = {};
    for (var pokemon in _pokemonList) {
      for (var type in pokemon.types) {
        distribution[type] = (distribution[type] ?? 0) + 1;
      }
    }
    return distribution;
  }

  @override
  void dispose() {
    _pokemonService.dispose();
    super.dispose();
  }
}
