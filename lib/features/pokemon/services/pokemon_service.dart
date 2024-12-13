// lib/features/pokemon/services/pokemon_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/api_paths.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/connectivity_manager.dart';
import '../../../core/utils/prefs_helper.dart';
import '../../../core/utils/cancellation_token.dart';
import '../models/pokemon_model.dart';
import '../models/pokemon_detail_model.dart';

/// Service responsible for fetching and caching Pokemon data.
/// Provides offline support and efficient data management.
class PokemonService {
  // Core dependencies
  final ApiHelper _apiHelper;
  final ConnectivityManager _connectivityManager;
  final PrefsHelper _prefsHelper;

  // Cache keys
  static const String _pokemonListKey = 'pokemon_list';
  static const String _pokemonDetailsKey = 'pokemon_details';
  static const Duration _cacheExpiration = Duration(hours: 24);

  // Stream controllers
  final _pokemonListController = StreamController<List<PokemonModel>>.broadcast();
  final _selectedPokemonController = StreamController<PokemonDetailModel?>.broadcast();

  // State management
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;

  // Constructor with dependency injection
  PokemonService({
    ApiHelper? apiHelper,
    ConnectivityManager? connectivityManager,
    PrefsHelper? prefsHelper,
  })  : _apiHelper = apiHelper ?? ApiHelper(),
        _connectivityManager = connectivityManager ?? ConnectivityManager(),
        _prefsHelper = prefsHelper ?? PrefsHelper();

  // Stream getters
  Stream<List<PokemonModel>> get pokemonList => _pokemonListController.stream;
  Stream<PokemonDetailModel?> get selectedPokemon => _selectedPokemonController.stream;

  /// Fetch Pokemon list with pagination and caching
  Future<List<PokemonModel>> getPokemonList({
    bool refresh = false,
    CancellationToken? cancellationToken,
  }) async {
    if (_isLoading || (!_hasMore && !refresh)) return [];
    _isLoading = true;

    try {
      if (refresh) {
        _currentPage = 0;
        _hasMore = true;
      }

      final offset = _currentPage * _pageSize;
      final cacheKey = '${_pokemonListKey}_${offset}_$_pageSize';

      final response = await _apiHelper.get<List<PokemonModel>>(
        endpoint: '${ApiPaths.kPokemon}?offset=$offset&limit=$_pageSize',
        parser: (json) => (json['results'] as List)
            .map((e) => PokemonModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        useCache: !refresh,
        cancellationToken: cancellationToken,
      );

      if (response.isSuccess && response.data != null) {
        final pokemonList = response.data!;
        _currentPage++;
        _hasMore = pokemonList.length >= _pageSize;

        if (!_pokemonListController.isClosed) {
          _pokemonListController.add(pokemonList);
        }

        return pokemonList;
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching Pokemon list: $e');
      }
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// Get detailed Pokemon information
  Future<PokemonDetailModel?> getPokemonDetail(
    String idOrName, {
    bool forceRefresh = false,
    CancellationToken? cancellationToken,
  }) async {
    try {
      final cacheKey = '${_pokemonDetailsKey}_$idOrName';

      final response = await _apiHelper.get<PokemonDetailModel>(
        endpoint: ApiPaths.getPokemonEndpoint(idOrName),
        parser: (json) => PokemonDetailModel.fromJson(json),
        useCache: !forceRefresh,
        cancellationToken: cancellationToken,
      );

      if (response.isSuccess && response.data != null) {
        if (!_selectedPokemonController.isClosed) {
          _selectedPokemonController.add(response.data);
        }
        return response.data;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching Pokemon detail: $e');
      }
      rethrow;
    }
  }

  /// Search Pokemon by name or ID
  Future<List<PokemonModel>> searchPokemon(
    String query, {
    CancellationToken? cancellationToken,
  }) async {
    try {
      if (query.isEmpty) return [];

      final response = await _apiHelper.get<List<PokemonModel>>(
        endpoint: '${ApiPaths.kPokemon}/search?q=$query',
        parser: (json) => (json['results'] as List)
            .map((e) => PokemonModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        useCache: false,
        cancellationToken: cancellationToken,
      );

      return response.isSuccess && response.data != null ? response.data! : [];
    } catch (e) {
      if (kDebugMode) {
        print('Error searching Pokemon: $e');
      }
      return [];
    }
  }

  /// Get Pokemon evolution chain
  Future<List<EvolutionStage>> getEvolutionChain(
    int id, {
    CancellationToken? cancellationToken,
  }) async {
    try {
      final response = await _apiHelper.get<List<EvolutionStage>>(
        endpoint: ApiPaths.getEvolutionChainEndpoint(id),
        parser: (json) => (json['chain'] as List)
            .map((e) => EvolutionStage.fromJson(e as Map<String, dynamic>))
            .toList(),
        useCache: true,
        cancellationToken: cancellationToken,
      );

      return response.isSuccess && response.data != null ? response.data! : [];
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching evolution chain: $e');
      }
      return [];
    }
  }

  /// Get type effectiveness chart
  Future<Map<String, double>> getTypeEffectiveness(
    List<String> types, {
    CancellationToken? cancellationToken,
  }) async {
    try {
      final effectiveness = <String, double>{};

      for (final type in types) {
        final response = await _apiHelper.get<Map<String, double>>(
          endpoint: ApiPaths.getTypeEndpoint(type),
          parser: (json) => Map<String, double>.from(
              json['damage_relations'] as Map<String, dynamic>),
          useCache: true,
          cancellationToken: cancellationToken,
        );

        if (response.isSuccess && response.data != null) {
          effectiveness.addAll(response.data!);
        }
      }

      return effectiveness;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching type effectiveness: $e');
      }
      return {};
    }
  }

  /// Clear cached data
  Future<void> clearCache() async {
    try {
      final prefs = _prefsHelper.prefs;
      final keys = prefs.getKeys().where((key) =>
          key.startsWith(_pokemonListKey) || key.startsWith(_pokemonDetailsKey));
      
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing cache: $e');
      }
    }
  }

  /// Proper resource disposal
  void dispose() {
    _pokemonListController.close();
    _selectedPokemonController.close();
  }
}