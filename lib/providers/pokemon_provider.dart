// lib/providers/pokemon_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../features/pokemon/models/pokemon_model.dart';
import '../features/pokemon/models/pokemon_detail_model.dart';
import '../features/pokemon/services/pokemon_service.dart';
import '../core/utils/connectivity_manager.dart';
import '../core/utils/api_helper.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';

class PokemonProvider extends ChangeNotifier {
  // Services
  final PokemonService _pokemonService = PokemonService();
  final ConnectivityManager _connectivityManager = ConnectivityManager();
  final FirebaseService _firebaseService = FirebaseService();
  final ApiHelper _apiHelper = ApiHelper();

  // Cache & Data Management
  final Map<String, Timer> _cacheExpiryTimers = {};
  final Map<String, Completer<void>> _pendingRequests = {};
  static const Duration _cacheTimeout = Duration(hours: 24);
  static const int _maxCacheItems = 100;

  // Pokemon Data Storage
  final List<PokemonModel> _pokemonList = [];
  List<PokemonModel> _filteredList = [];
  final Map<int, PokemonDetailModel> _pokemonDetails = {};

  // Network State Management
  StreamSubscription<NetworkState>? _networkSubscription;
  bool _isOffline = false;
  bool _isWeakConnection = false;
  bool _isSyncing = false;

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
  bool get isOffline => _isOffline;
  bool get isSyncing => _isSyncing;

  PokemonProvider() {
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    try {
      await _connectivityManager.initialize();
      await _apiHelper.initialize();

      _networkSubscription = _connectivityManager.networkStateStream
          .listen(_handleNetworkStateChange);

      // Initial network check
      _isOffline = !_connectivityManager.isOnline;
      _isWeakConnection = _connectivityManager.currentState.needsOptimization;

      if (kDebugMode) {
        print('✅ Pokemon Provider initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Pokemon Provider: $e');
      }
      _error = 'Failed to initialize provider';
    }
  }

  void _handleNetworkStateChange(NetworkState state) {
    final wasOffline = _isOffline;
    _isOffline = !state.isOnline;
    _isWeakConnection = state.needsOptimization;

    if (wasOffline && state.isOnline) {
      _syncDataAfterOffline();
    }

    if (!wasOffline && !state.isOnline) {
      _handleOfflineTransition();
    }

    notifyListeners();
  }

  Future<void> _syncDataAfterOffline() async {
    if (_isSyncing || _isDisposed) return;

    try {
      _isSyncing = true;
      notifyListeners();

      if (_pokemonList.isEmpty) {
        await initializePokemonList();
      } else {
        await refreshPokemonList();
      }

      _error = '';
    } catch (e) {
      _error = 'Failed to sync data';
      if (kDebugMode) {
        print('❌ Sync error: $e');
      }
    } finally {
      _isSyncing = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  void _handleOfflineTransition() {
    cancelAllRequests();
    _error = 'Working in offline mode. Some features may be limited.';
    notifyListeners();
  }

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

      if (_isOffline) {
        final cachedData = await _loadFromCache();
        if (cachedData.isEmpty && _pokemonList.isEmpty) {
          _error = 'No cached data available offline';
        }
        return;
      }

      _requestTokens['pokemon_list']?.cancel();
      final token = CancellationToken();
      _requestTokens['pokemon_list'] = token;

      final newPokemon = await _executeRequest(
        'pokemon_list_$_currentPage',
        () => _pokemonService.getPokemonList(
          offset: _currentPage * 20,
          limit: _isWeakConnection ? 10 : 20,
          cancellationToken: token,
        ),
      );

      if (newPokemon != null) {
        _pokemonList.addAll(newPokemon);
        _filterPokemon(_searchQuery);
        _currentPage++;
        _hasMore = newPokemon.length == (_isWeakConnection ? 10 : 20);
        _error = '';

        await _cacheData(newPokemon);

        // Sync with Firebase if authenticated
        if (isAuthenticated) {
          await _syncWithFirebase(newPokemon);
        }
      }
    } catch (e) {
      if (e is! RequestCancelledException) {
        _error = e.toString();
        if (kDebugMode) {
          print('❌ Error loading Pokemon: $_error');
        }
      }
    } finally {
      _setLoading(false);
      _isLoadingMore = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<PokemonDetailModel?> getPokemonDetail(int id) async {
    if (_pokemonDetails.containsKey(id)) {
      _setCacheExpiry(id);
      return _pokemonDetails[id];
    }

    try {
      if (_isOffline) {
        return await _loadDetailFromCache(id);
      }

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
        await _cacheDetailData(id, detail);

        if (!_isDisposed) {
          notifyListeners();
        }
        return detail;
      }
      return null;
    } catch (e) {
      if (e is! RequestCancelledException) {
        _error = e.toString();
        if (kDebugMode) {
          print('❌ Error loading Pokemon detail: $_error');
        }
      }
      return null;
    } finally {
      _requestTokens.remove(id.toString());
    }
  }

  Future<void> searchPokemon(String query) async {
    _searchQuery = query.toLowerCase();
    _filterPokemon(_searchQuery);
    notifyListeners();

    // Load more if results are few and not offline
    if (_filteredList.length < 5 && !_isOffline && _hasMore) {
      await loadPokemon();
    }
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

  Future<T?> _executeRequest<T>(
      String key, Future<T> Function() request) async {
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

  Future<void> _syncWithFirebase(List<PokemonModel> pokemon) async {
    if (!isAuthenticated) return;

    try {
      final userId = _authProvider?.user?.uid;
      if (userId == null) return;

      await _firebaseService.updateUserData(userId, {
        'lastSync': DateTime.now().toIso8601String(),
        'pokemonCount': _pokemonList.length,
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase sync error: $e');
      }
    }
  }

  Future<void> _cacheData(List<PokemonModel> pokemon) async {
    try {
      final cacheKey = 'pokemon_list_$_currentPage';
      await _apiHelper.cacheResponse(cacheKey, pokemon);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Cache error: $e');
      }
    }
  }

  Future<void> _cacheDetailData(int id, PokemonDetailModel detail) async {
    try {
      final cacheKey = 'pokemon_detail_$id';
      await _apiHelper.cacheResponse(cacheKey, detail);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Detail cache error: $e');
      }
    }
  }

  Future<List<PokemonModel>> _loadFromCache() async {
    try {
      final cacheKey = 'pokemon_list_$_currentPage';
      final cachedData = await _apiHelper.getCachedResponse(cacheKey);
      if (cachedData != null) {
        return (cachedData as List)
            .map((item) => PokemonModel.fromJson(item))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Cache load error: $e');
      }
    }
    return [];
  }

  Future<PokemonDetailModel?> _loadDetailFromCache(int id) async {
    try {
      final cacheKey = 'pokemon_detail_$id';
      final cachedData = await _apiHelper.getCachedResponse(cacheKey);
      if (cachedData != null) {
        return PokemonDetailModel.fromJson(cachedData);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Detail cache load error: $e');
      }
    }
    return null;
  }

  void _cleanupCache() {
    if (_pokemonDetails.length > _maxCacheItems) {
      final sortedKeys = _pokemonDetails.keys.toList()
        ..sort((a, b) => (_cacheExpiryTimers[a.toString()]?.tick ?? 0)
            .compareTo(_cacheExpiryTimers[b.toString()]?.tick ?? 0));

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
      final userId = _authProvider!.user!.uid;
      final userDoc = await _firebaseService.getUserDocument(userId);

      if (userDoc != null) {
        // Load user-specific Pokemon preferences if any
        final favorites = userDoc['favorites'] as List? ?? [];
        for (var id in favorites) {
          if (!_pokemonDetails.containsKey(id)) {
            await getPokemonDetail(id);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading user preferences: $e');
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

  @override
  void dispose() {
    _isDisposed = true;
    _networkSubscription?.cancel();
    cancelAllRequests();
    for (var timer in _cacheExpiryTimers.values) {
      timer.cancel();
    }
    _cacheExpiryTimers.clear();
    _pendingRequests.clear();
    super.dispose();
  }
}
