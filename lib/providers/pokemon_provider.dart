// lib/providers/pokemon_provider.dart

/// Pokemon provider to manage Pokemon data state.
/// Handles Pokemon data fetching, caching, and favorites management.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../features/auth/models/user_model.dart';
import '../features/pokemon/models/pokemon_model.dart';
import '../features/pokemon/models/pokemon_detail_model.dart';
import '../features/favorites/models/favorite_model.dart';

/// Pokemon fetch state
enum PokemonFetchState {
  /// Initial state
  initial,

  /// Loading data
  loading,

  /// Data loaded successfully
  loaded,

  /// Loading more data (pagination)
  loadingMore,

  /// All data loaded
  complete,

  /// Error state
  error
}

/// Pokemon provider
class PokemonProvider with ChangeNotifier {
  // Dependencies
  final ApiService _apiService;
  final FirebaseService _firebaseService;

  // Internal state
  PokemonFetchState _state = PokemonFetchState.initial;
  final List<PokemonModel> _pokemonList = [];
  final Map<int, PokemonDetailModel> _pokemonDetails = {};
  final Map<int, bool> _favorites = {};
  String? _error;
  bool _hasMore = true;
  int _currentPage = 0;
  String _searchQuery = '';
  List<String> _selectedTypes = [];

  // Pagination
  static const int pageSize = 20;

  // Streams
  StreamSubscription<List<FavoriteModel>>? _favoritesSubscription;

  /// Constructor
  PokemonProvider({
    ApiService? apiService,
    FirebaseService? firebaseService,
  })  : _apiService = apiService ?? ApiService(),
        _firebaseService = firebaseService ?? FirebaseService() {
    _initialize();
  }

  /// Getters
  PokemonFetchState get state => _state;
  List<PokemonModel> get pokemonList => _pokemonList;
  String? get error => _error;
  bool get hasMore => _hasMore;
  String get searchQuery => _searchQuery;
  List<String> get selectedTypes => _selectedTypes;

  /// Initialize provider
  Future<void> _initialize() async {
    try {
      await _apiService.initialize();
      await loadPokemonList();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Start listening to favorites
  void startListeningToFavorites(UserModel user) {
    _favoritesSubscription?.cancel();
    _favoritesSubscription =
        _firebaseService.getFavoritesStream(user.id).listen(
              _handleFavoritesUpdate,
              onError: _handleError,
            );
  }

  /// Stop listening to favorites
  void stopListeningToFavorites() {
    _favoritesSubscription?.cancel();
    _favorites.clear();
    notifyListeners();
  }

  /// Load Pokemon list
  Future<void> loadPokemonList({bool refresh = false}) async {
    if (_state == PokemonFetchState.loading ||
        _state == PokemonFetchState.loadingMore) {
      return;
    }

    try {
      if (refresh) {
        _state = PokemonFetchState.loading;
        _currentPage = 0;
        _pokemonList.clear();
        _hasMore = true;
      } else {
        _state = _pokemonList.isEmpty
            ? PokemonFetchState.loading
            : PokemonFetchState.loadingMore;
      }
      notifyListeners();

      final pokemon = await _apiService.getPokemonList(
        offset: _currentPage * pageSize,
        limit: pageSize,
      );

      if (pokemon.isEmpty) {
        _hasMore = false;
      } else {
        _pokemonList.addAll(pokemon);
        _currentPage++;
      }

      _state = PokemonFetchState.loaded;
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Get Pokemon detail
  Future<PokemonDetailModel?> getPokemonDetail(int id) async {
    try {
      if (_pokemonDetails.containsKey(id)) {
        return _pokemonDetails[id];
      }

      final detail = await _apiService.getPokemonDetail(id);
      _pokemonDetails[id] = detail;
      return detail;
    } catch (e) {
      _handleError(e);
      return null;
    }
  }

  /// Search Pokemon
  Future<void> search(String query) async {
    _searchQuery = query.toLowerCase();
    await refresh();
  }

  /// Filter by types
  Future<void> filterByTypes(List<String> types) async {
    _selectedTypes = types;
    await refresh();
  }

  /// Refresh Pokemon list
  Future<void> refresh() async {
    await loadPokemonList(refresh: true);
  }

  /// Add to favorites
  Future<void> addToFavorites(
    UserModel user,
    PokemonModel pokemon, {
    String? note,
    String? nickname,
  }) async {
    try {
      await _firebaseService.addToFavorites(
        userId: user.id,
        pokemon: pokemon,
        note: note,
        nickname: nickname,
      );
      _favorites[pokemon.id] = true;
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Remove from favorites
  Future<void> removeFromFavorites(
    UserModel user,
    PokemonModel pokemon,
  ) async {
    try {
      final favoriteId = '${user.id}_${pokemon.id}';
      await _firebaseService.removeFromFavorites(
        userId: user.id,
        favoriteId: favoriteId,
      );
      _favorites[pokemon.id] = false;
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Check if Pokemon is favorite
  bool isFavorite(int pokemonId) => _favorites[pokemonId] ?? false;

  /// Get filtered Pokemon list
  List<PokemonModel> getFilteredPokemon() {
    return _pokemonList.where((pokemon) {
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final nameMatch = pokemon.name.toLowerCase().contains(_searchQuery);
        final idMatch = pokemon.id.toString().contains(_searchQuery);
        if (!nameMatch && !idMatch) return false;
      }

      // Apply type filter
      if (_selectedTypes.isNotEmpty) {
        final hasType = pokemon.types
            .any((type) => _selectedTypes.contains(type.toLowerCase()));
        if (!hasType) return false;
      }

      return true;
    }).toList();
  }

  /// Handle favorites update
  void _handleFavoritesUpdate(List<FavoriteModel> favorites) {
    _favorites.clear();
    for (var favorite in favorites) {
      _favorites[favorite.pokemon.id] = true;
    }
    notifyListeners();
  }

  /// Handle errors
  void _handleError(dynamic error) {
    _state = PokemonFetchState.error;
    _error = error.toString();
    notifyListeners();

    if (kDebugMode) {
      print('🚫 Pokemon Error: $error');
    }
  }

  /// Clear error state
  void clearError() {
    _error = null;
    _state = _pokemonList.isEmpty
        ? PokemonFetchState.initial
        : PokemonFetchState.loaded;
    notifyListeners();
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    super.dispose();
  }
}
