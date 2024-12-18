// lib/services/api_service.dart

/// Pokemon API service to handle all PokeAPI interactions.
/// Provides methods for fetching Pokemon data with proper caching and error handling.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants/api_paths.dart';
import '../core/utils/monitoring_manager.dart';
import '../core/utils/connectivity_manager.dart';
import '../core/utils/cache_manager.dart';
import '../features/pokemon/models/pokemon_model.dart';
import '../features/pokemon/models/pokemon_detail_model.dart';
import '../features/pokemon/models/pokemon_move_model.dart';

/// Pokemon API service errors
class ApiServiceError implements Exception {
  /// Error message
  final String message;

  /// HTTP status code if applicable
  final int? statusCode;

  /// API endpoint that caused error
  final String? endpoint;

  /// Constructor
  const ApiServiceError({
    required this.message,
    this.statusCode,
    this.endpoint,
  });

  @override
  String toString() => 'ApiServiceError: $message';
}

/// Pokemon API service for handling API requests and caching
class ApiService {
  // Singleton implementation
  static final ApiService _instance = ApiService._internal();

  /// Singleton instance getter
  factory ApiService() => _instance;

  ApiService._internal();

  // Dependencies
  late final MonitoringManager _monitoring;
  late final ConnectivityManager _connectivity;
  late final CacheManager _cache;

  // Internal state
  bool _isInitialized = false;
  final _client = http.Client();

  // Configuration constants
  static const Duration _cacheExpiration = Duration(hours: 24);
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  static const int _baseDelaySeconds = 2;

  /// Initialize service and its dependencies
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _monitoring = MonitoringManager();
      _connectivity = ConnectivityManager();
      _cache = await CacheManager.initialize();

      _isInitialized = true;

      if (kDebugMode) {
        print('✅ API Service initialized');
      }
    } catch (e) {
      _monitoring.logError(
        'API Service initialization failed',
        error: e,
        additionalData: {'timestamp': DateTime.now().toIso8601String()},
      );
      rethrow;
    }
  }

  /// Get Pokemon list with pagination
  ///
  /// [offset] Starting index for pagination
  /// [limit] Number of items to fetch
  /// [forceRefresh] Whether to bypass cache
  Future<List<PokemonModel>> getPokemonList({
    int offset = 0,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    _checkInitialization();
    final cacheKey = CacheKeys.pokemonList(limit, offset);

    try {
      // Handle offline mode
      if (!_connectivity.hasConnection && !forceRefresh) {
        final cached = await _getFromCache<List<dynamic>>(cacheKey);
        if (cached != null) {
          return cached
              .map(
                  (json) => PokemonModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
        throw const ApiServiceError(message: 'No internet connection');
      }

      // Check cache first
      if (!forceRefresh) {
        final cached = await _getFromCache<List<dynamic>>(cacheKey);
        if (cached != null) {
          return cached
              .map(
                  (json) => PokemonModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }

      // Fetch from API
      final response = await _get(ApiPaths.pokemonList(limit, offset));
      final results = response['results'] as List<dynamic>;
      final List<PokemonModel> pokemonList = [];

      for (final pokemon in results) {
        final url = pokemon['url'] as String;
        final detailResponse = await _get(url);
        pokemonList.add(_mapPokemonResponse(detailResponse));
      }

      // Cache results
      await _saveToCache(cacheKey, pokemonList.map((p) => p.toJson()).toList());
      return pokemonList;
    } catch (e) {
      _monitoring.logError(
        'Failed to fetch Pokemon list',
        error: e,
        additionalData: {
          'offset': offset,
          'limit': limit,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      rethrow;
    }
  }

  /// Get detailed Pokemon information by ID
  ///
  /// [id] Pokemon ID to fetch
  /// [forceRefresh] Whether to bypass cache
  Future<PokemonDetailModel> getPokemonDetail(
    int id, {
    bool forceRefresh = false,
  }) async {
    _checkInitialization();
    final cacheKey = CacheKeys.pokemonDetails(id);

    try {
      // Handle offline mode
      if (!_connectivity.hasConnection && !forceRefresh) {
        final cached = await _getFromCache<Map<String, dynamic>>(cacheKey);
        if (cached != null) {
          return PokemonDetailModel.fromJson(cached);
        }
        throw const ApiServiceError(message: 'No internet connection');
      }

      // Check cache first
      if (!forceRefresh) {
        final cached = await _getFromCache<Map<String, dynamic>>(cacheKey);
        if (cached != null) {
          return PokemonDetailModel.fromJson(cached);
        }
      }

      // Fetch all required data
      final pokemonData = await _get(ApiPaths.pokemonDetails(id));
      final speciesData = await _get(ApiPaths.pokemonSpecies(id));
      final evolutionChainUrl = speciesData['evolution_chain']['url'] as String;
      final evolutionData = await _get(evolutionChainUrl);

      // Build complete model
      final detailModel = await _buildPokemonDetail(
        pokemonData: pokemonData,
        speciesData: speciesData,
        evolutionData: evolutionData,
      );

      // Cache results
      await _saveToCache(cacheKey, detailModel.toJson());
      return detailModel;
    } catch (e) {
      _monitoring.logError(
        'Failed to fetch Pokemon detail',
        error: e,
        additionalData: {
          'pokemonId': id,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      rethrow;
    }
  }

  /// Get cached data by key with type safety
  Future<T?> _getFromCache<T>(String key) async {
    try {
      final data = await _cache.get<T>(key);
      if (data != null) {
        _monitoring.logPerformanceMetric(
          type: MetricType.cache,
          value: 1.0,
          additionalData: {'key': key, 'hit': true},
        );
      }
      return data;
    } catch (e) {
      _monitoring.logError(
        'Cache read error',
        error: e,
        additionalData: {'key': key},
      );
      return null;
    }
  }

  /// Save data to cache
  Future<void> _saveToCache<T>(String key, T data) async {
    try {
      await _cache.put(key, data);
      _monitoring.logPerformanceMetric(
        type: MetricType.cache,
        value: 1.0,
        additionalData: {'key': key, 'write': true},
      );
    } catch (e) {
      _monitoring.logError(
        'Cache write error',
        error: e,
        additionalData: {'key': key},
      );
    }
  }

  /// Execute GET request with retry logic
  Future<Map<String, dynamic>> _get(
    String endpoint, {
    Duration timeout = _defaultTimeout,
    int retryCount = 0,
  }) async {
    try {
      final response = await _client.get(Uri.parse(endpoint)).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      // Handle rate limiting with exponential backoff
      if (response.statusCode == 429 && retryCount < _maxRetries) {
        final delay = math.pow(_baseDelaySeconds, retryCount).toInt();
        await Future.delayed(Duration(seconds: delay));
        return _get(endpoint, retryCount: retryCount + 1);
      }

      throw ApiServiceError(
        message: 'HTTP Error ${response.statusCode}',
        statusCode: response.statusCode,
        endpoint: endpoint,
      );
    } on TimeoutException {
      throw const ApiServiceError(message: 'Request timed out');
    } catch (e) {
      if (e is ApiServiceError) rethrow;
      throw ApiServiceError(message: e.toString());
    }
  }

  /// Map basic Pokemon response to model
  PokemonModel _mapPokemonResponse(Map<String, dynamic> data) {
    return PokemonModel(
      id: data['id'] as int,
      name: data['name'] as String,
      types: (data['types'] as List<dynamic>)
          .map((t) => t['type']['name'] as String)
          .toList(),
      spriteUrl: data['sprites']['other']['official-artwork']['front_default']
              as String? ??
          data['sprites']['front_default'] as String,
      stats: _mapPokemonStats(data['stats'] as List<dynamic>),
      height: data['height'] as int,
      weight: data['weight'] as int,
      baseExperience: data['base_experience'] as int? ?? 0,
      species: data['species']['name'] as String,
    );
  }

  /// Map Pokemon stats from API response
  PokemonStats _mapPokemonStats(List<dynamic> stats) {
    int getStat(String name) {
      return stats.firstWhere(
            (s) => s['stat']['name'] == name,
            orElse: () => {'base_stat': 0},
          )['base_stat'] as int? ??
          0;
    }

    return PokemonStats(
      hp: getStat('hp'),
      attack: getStat('attack'),
      defense: getStat('defense'),
      specialAttack: getStat('special-attack'),
      specialDefense: getStat('special-defense'),
      speed: getStat('speed'),
    );
  }

  /// Build complete Pokemon detail model
  Future<PokemonDetailModel> _buildPokemonDetail({
    required Map<String, dynamic> pokemonData,
    required Map<String, dynamic> speciesData,
    required Map<String, dynamic> evolutionData,
  }) async {
    final basicPokemon = _mapPokemonResponse(pokemonData);
    final abilities =
        await _mapAbilities(pokemonData['abilities'] as List<dynamic>);
    final moves = await _mapMoves(pokemonData['moves'] as List<dynamic>);
    final evolutionChain = await _mapEvolutionChain(
        evolutionData['chain'] as Map<String, dynamic>);

    return PokemonDetailModel(
      id: basicPokemon.id,
      name: basicPokemon.name,
      types: basicPokemon.types,
      spriteUrl: basicPokemon.spriteUrl,
      stats: basicPokemon.stats,
      height: basicPokemon.height,
      weight: basicPokemon.weight,
      baseExperience: basicPokemon.baseExperience,
      species: basicPokemon.species,
      abilities: abilities,
      moves: moves,
      evolutionChain: evolutionChain,
      description: _getEnglishDescription(
          speciesData['flavor_text_entries'] as List<dynamic>),
      catchRate: speciesData['capture_rate'] as int,
      eggGroups: (speciesData['egg_groups'] as List<dynamic>)
          .map((g) => g['name'] as String)
          .toList(),
      genderRatio: (speciesData['gender_rate'] as int).toDouble() * 12.5,
      generation:
          int.parse((speciesData['generation']['url'] as String).split('/')[6]),
      habitat: (speciesData['habitat'] as Map<String, dynamic>?)?['name']
              as String? ??
          'unknown',
    );
  }

  /// Map Pokemon abilities with full details
  Future<List<PokemonAbility>> _mapAbilities(List<dynamic> abilities) async {
    final mappedAbilities = <PokemonAbility>[];

    for (final ability in abilities) {
      final abilityUrl = ability['ability']['url'] as String;
      final abilityData = await _get(abilityUrl);
      final effectEntries = abilityData['effect_entries'] as List<dynamic>;

      final description = effectEntries.firstWhere(
        (entry) => entry['language']['name'] == 'en',
        orElse: () => {'effect': 'No description available.'},
      )['effect'] as String;

      mappedAbilities.add(PokemonAbility(
        name: ability['ability']['name'] as String,
        description: description,
        isHidden: ability['is_hidden'] as bool,
      ));
    }

    return mappedAbilities;
  }

  /// Map Pokemon moves with full details
  Future<List<PokemonMove>> _mapMoves(List<dynamic> moves) async {
    final mappedMoves = <PokemonMove>[];

    for (final move in moves) {
      final moveUrl = move['move']['url'] as String;
      final moveData = await _get(moveUrl);
      final effectEntries = moveData['effect_entries'] as List<dynamic>;

      final description = effectEntries.firstWhere(
        (entry) => entry['language']['name'] == 'en',
        orElse: () => {'effect': 'No description available.'},
      )['effect'] as String;

      mappedMoves.add(PokemonMove(
        name: moveData['name'] as String,
        type: moveData['type']['name'] as String,
        power: moveData['power'] as int?,
        accuracy: moveData['accuracy'] as int?,
        pp: moveData['pp'] as int? ?? 0,
        description: description,
      ));
    }

    return mappedMoves;
  }

  /// Map evolution chain data
  Future<List<EvolutionStage>> _mapEvolutionChain(
      Map<String, dynamic> chain) async {
    final stages = <EvolutionStage>[];

    Future<void> processChain(Map<String, dynamic> currentChain) async {
      final species = currentChain['species'] as Map<String, dynamic>;
      final evolvesTo = currentChain['evolves_to'] as List<dynamic>;
      final details = currentChain['evolution_details'] as List<dynamic>;

      final pokemonId = int.parse(
        (species['url'] as String).split('/')[6],
      );

      final pokemonData = await _get(ApiPaths.pokemonDetails(pokemonId));
      final spriteUrl = pokemonData['sprites']['other']['official-artwork']
              ['front_default'] as String? ??
          pokemonData['sprites']['front_default'] as String;

      final firstEvolution =
          details.isNotEmpty ? details[0] as Map<String, dynamic> : null;

      stages.add(EvolutionStage(
        pokemonId: pokemonId,
        name: species['name'] as String,
        spriteUrl: spriteUrl,
        level: firstEvolution?['min_level'] as int?,
        trigger: firstEvolution?['trigger']?['name'] as String?,
        item: firstEvolution?['item']?['name'] as String?,
      ));

      // Process next evolution stage recursively
      for (final evolution in evolvesTo) {
        await processChain(evolution as Map<String, dynamic>);
      }
    }

    await processChain(chain);
    return stages;
  }

  /// Get English description from flavor text entries
  String _getEnglishDescription(List<dynamic> entries) {
    final entry = entries.firstWhere(
      (entry) => entry['language']['name'] == 'en',
      orElse: () => {'flavor_text': 'No description available.'},
    );

    return ((entry['flavor_text'] as String?) ?? 'No description available.')
        .replaceAll('\n', ' ')
        .replaceAll('\f', ' ')
        .trim();
  }

  /// Check if service is initialized
  void _checkInitialization() {
    if (!_isInitialized) {
      throw const ApiServiceError(message: 'API Service not initialized');
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    _checkInitialization();
    await _cache.clear();
  }

  /// Clean up resources
  void dispose() {
    _client.close();
    _isInitialized = false;
    if (kDebugMode) {
      print('🧹 API Service disposed');
    }
  }
}
