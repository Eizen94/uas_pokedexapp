// lib/providers/pokemon_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import '../features/pokemon/models/pokemon_model.dart';
import '../features/pokemon/models/pokemon_detail_model.dart';
import '../features/pokemon/services/pokemon_service.dart';
import '../core/utils/request_manager.dart';
import '../core/utils/connectivity_manager.dart';
import '../core/utils/cancellation_token.dart';
import 'auth_provider.dart';

class PokemonProvider extends ChangeNotifier {
  // Services
  final PokemonService _pokemonService = PokemonService();
  final ConnectivityManager _connectivityManager = ConnectivityManager();

  // Cache & Data Management
  final Map<String, Timer> _cacheExpiryTimers = {};
  final Map<String, Completer<void>> _pendingRequests = {};
  static const Duration _cacheTimeout = Duration(hours: 24);
  static const int _maxCacheItems = 100;

  // Pokemon Data Storage
  final List<PokemonModel> _pokemonList = [];
  List<PokemonModel> _filteredList = [];
  final Map<int, PokemonDetailModel> _pokemonDetails = {};

  // Pagination & Search
  int _currentPage = 0;
  bool _hasMore = true;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _error = '';

  // Request Tracking & Memory Management
  final Map<String, CancellationToken> _requestTokens = {};
  bool _isDisposed = false;

  // Auth State
  AppAuthProvider? _authProvider;
  bool get isAuthenticated => _authProvider?.isAuthenticated ?? false;

  // Public Getters
  List<PokemonModel> get pokemonList => _filteredList;
  Map<int, PokemonDetailModel> get pokemonDetails =>
      Map.unmodifiable(_pokemonDetails);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String get error => _error;
  bool get hasError => _error.isNotEmpty;
  String get searchQuery => _searchQuery;
  int get currentPage => _currentPage;

  // Memory Management Methods
  void _cleanupCache() {
    if (_pokemonDetails.length > _maxCacheItems) {
      // Remove least recently used items
      final sortedKeys = _pokemonDetails.keys.toList()
        ..sort((a, b) =>
            _cacheExpiryTimers[a.toString()]?.tick.compareTo(
                  _cacheExpiryTimers[b.toString()]?.tick ?? 0,
                ) ??
            0);

      for (var i = 0; i < sortedKeys.length - _maxCacheItems; i++) {
        _removeFromCache(sortedKeys[i]);
      }
    }
  }

  void _removeFromCache(int id) {
    _pokemonDetails.remove(id);
    _cacheExpiryTimers[id.toString()]?.cancel();
    _cacheExpiryTimers.remove(id.toString());
  }

  void _setCacheExpiry(int id) {
    _cacheExpiryTimers[id.toString()]?.cancel();
    _cacheExpiryTimers[id.toString()] = Timer(_cacheTimeout, () {
      if (!_isDisposed) {
        _removeFromCache(id);
      }
    });
  }

  // Request Management
  Future<T?> _executeRequest<T>(
    String key,
    Future<T> Function() request,
  ) async {
    // Check for pending request
    if (_pendingRequests.containsKey(key)) {
      return _pendingRequests[key]!.future.then((_) => null);
    }

    final completer = Completer<void>();
    _pendingRequests[key] = completer;

    try {
      final result = await request();
      completer.complete();
      _pendingRequests.remove(key);
      return result;
    } catch (e) {
      completer.completeError(e);
      _pendingRequests.remove(key);
      rethrow;
    }
  }

  // Pokemon List Management
  Future<void> initializePokemonList() async {
    if (_pokemonList.isEmpty) {
      await loadPokemon(showLoading: true);
    }
  }

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

      // Cancel previous request
      _requestTokens['pokemon_list']?.cancel();
      final token = CancellationToken();
      _requestTokens['pokemon_list'] = token;

      final newPokemon = await _executeRequest(
        'pokemon_list_$_currentPage',
        () => _pokemonService.getPokemonList(
          offset: _currentPage * 20,
          limit: 20,
          cancellationToken: token,
        ),
      );

      if (newPokemon != null) {
        _pokemonList.addAll(newPokemon);
        _filterPokemon(_searchQuery);
        _currentPage++;
        _hasMore = newPokemon.length == 20;
        _error = '';
      }
    } catch (e) {
      if (e is! RequestCancelledException) {
        _error = e.toString();
        if (kDebugMode) {
          print('Error loading Pokemon: $_error');
        }
      }
    } finally {
      _setLoading(false);
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Pokemon Detail Management
  Future<PokemonDetailModel?> getPokemonDetail(int id) async {
    if (_pokemonDetails.containsKey(id)) {
      _setCacheExpiry(id); // Reset expiry timer
      return _pokemonDetails[id];
    }

    try {
      // Cancel previous request for this ID
      _requestTokens[id.toString()]?.cancel();
      final token = CancellationToken();
      _requestTokens[id.toString()] = token;

      final detail = await _executeRequest(
        'pokemon_detail_$id',
        () => _pokemonService.getPokemonDetail(
          id.toString(),
          cancellationToken: token,
        ),
      );

      if (detail != null) {
        _pokemonDetails[id] = detail;
        _cleanupCache();
        _setCacheExpiry(id);
        notifyListeners();
        return detail;
      }
      return null;
    } catch (e) {
      if (e is! RequestCancelledException) {
        _error = e.toString();
        if (kDebugMode) {
          print('Error loading Pokemon detail: $_error');
        }
      }
      return null;
    } finally {
      _requestTokens.remove(id.toString());
    }
  }

  // Search & Filter
  void searchPokemon(String query) {
    _searchQuery = query.toLowerCase();
    _filterPokemon(_searchQuery);
    notifyListeners();
  }

  void _filterPokemon(String query) {
    if (query.isEmpty) {
      _filteredList = List.from(_pokemonList);
    } else {
      _filteredList = _pokemonList.where((pokemon) {
        return pokemon.name.toLowerCase().contains(query) ||
            pokemon.id.toString() == query ||
            pokemon.types.any((type) => type.toLowerCase().contains(query));
      }).toList();
    }
  }

  // Refresh & Reset
  Future<void> refreshPokemonList() async {
    _pokemonList.clear();
    _filteredList.clear();
    await clearPokemonDetailsCache();
    _currentPage = 0;
    _hasMore = true;
    _error = '';
    _searchQuery = '';

    cancelAllRequests();
    notifyListeners();

    await loadPokemon(showLoading: true);
  }

  Future<void> clearPokemonDetailsCache() async {
    for (var id in _pokemonDetails.keys) {
      _removeFromCache(id);
    }
    _pokemonDetails.clear();
    notifyListeners();
  }

  // Request Management
  void cancelPokemonDetailRequest(int id) {
    final token = _requestTokens[id.toString()];
    if (token != null) {
      token.cancel();
      _requestTokens.remove(id.toString());
    }
  }

  void cancelAllRequests() {
    for (var token in _requestTokens.values) {
      token.cancel();
    }
    _requestTokens.clear();
    _pokemonService.cancelAllRequests();
  }

  // State Management
  void _setLoading(bool value) {
    _isLoading = value;
    if (!value) {
      _isLoadingMore = false;
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  // Auth State Management
  void updateAuth(AppAuthProvider auth) {
    _authProvider = auth;
    if (auth.isAuthenticated) {
      _loadUserPreferences();
    } else {
      _resetState();
    }
  }

  Future<void> _loadUserPreferences() async {
    if (_authProvider?.user == null) return;
    try {
      // Load user preferences like favorite Pokemon, view settings, etc.
      // Implement when needed
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user preferences: $e');
      }
    }
  }

  void _resetState() {
    _pokemonList.clear();
    _filteredList.clear();
    _pokemonDetails.clear();
    _currentPage = 0;
    _hasMore = true;
    _error = '';
    _searchQuery = '';
    cancelAllRequests();
    notifyListeners();
  }

  // Resource Cleanup
  @override
  void dispose() {
    _isDisposed = true;
    cancelAllRequests();
    for (var timer in _cacheExpiryTimers.values) {
      timer.cancel();
    }
    _cacheExpiryTimers.clear();
    _pendingRequests.clear();
    super.dispose();
  }
}
