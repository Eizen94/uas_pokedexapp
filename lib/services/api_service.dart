// lib/services/api_service.dart

/// Pokemon API service to handle all PokeAPI interactions.
/// Provides methods for fetching Pokemon data with proper caching and error handling.
library;

import 'dart:async';
import 'dart:convert';
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
  final String message;
  final int? statusCode;
  final String? endpoint;

  const ApiServiceError({
    required this.message,
    this.statusCode,
    this.endpoint,
  });

  @override
  String toString() => 'ApiServiceError: $message';
}

/// Pokemon API service
class ApiService {
  // Singleton implementation
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Dependencies
  late final MonitoringManager _monitoring;
  late final ConnectivityManager _connectivity;
  late final CacheManager _cache;

  // Internal state
  bool _isInitialized = false;
  final _client = http.Client();

  // Cache configuration
  static const Duration _cacheExpiration = Duration(hours: 24);
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;

  /// Initialize service
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
      _monitoring.logError('API Service initialization failed', error: e);
      rethrow;
    }
  }

  /// Get Pokemon list with pagination
  Future<List<PokemonModel>> getPokemonList({
    int offset = 0,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = CacheKeys.pokemonList(limit, offset);

    try {
      // Check cache first
      if (!forceRefresh) {
        final cached = await _cache.get<List<dynamic>>(cacheKey);
        if (cached != null) {
          return cached
              .map(
                  (json) => PokemonModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }

      // Fetch from API
      final response = await _get(
        ApiPaths.pokemonList(limit, offset),
      );

      final results = response['results'] as List<dynamic>;
      final List<PokemonModel> pokemonList = [];

      // Fetch details for each Pokemon
      for (final pokemon in results) {
        final url = pokemon['url'] as String;
        final detailResponse = await _get(url);
        pokemonList.add(_mapPokemonResponse(detailResponse));
      }

      // Cache results
      await _cache.put(cacheKey, pokemonList.map((p) => p.toJson()).toList());

      return pokemonList;
    } catch (e) {
      _monitoring.logError(
        'Failed to fetch Pokemon list',
        error: e,
        additionalData: {'offset': offset, 'limit': limit},
      );
      rethrow;
    }
  }

  /// Get detailed Pokemon information
  Future<PokemonDetailModel> getPokemonDetail(
    int id, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = CacheKeys.pokemonDetails(id);

    try {
      // Check cache first
      if (!forceRefresh) {
        final cached = await _cache.get<Map<String, dynamic>>(cacheKey);
        if (cached != null) {
          return PokemonDetailModel.fromJson(cached);
        }
      }

      // Get basic Pokemon data
      final pokemonData = await _get(ApiPaths.pokemonDetails(id));

      // Get species data
      final speciesData = await _get(ApiPaths.pokemonSpecies(id));

      // Get evolution chain data
      final evolutionChainUrl = speciesData['evolution_chain']['url'] as String;
      final evolutionData = await _get(evolutionChainUrl);

      // Build complete Pokemon detail
      final detailModel = await _mapPokemonDetailResponse(
        pokemonData: pokemonData,
        speciesData: speciesData,
        evolutionData: evolutionData,
      );

      // Cache result
      await _cache.put(cacheKey, detailModel.toJson());

      return detailModel;
    } catch (e) {
      _monitoring.logError(
        'Failed to fetch Pokemon detail',
        error: e,
        additionalData: {'pokemonId': id},
      );
      rethrow;
    }
  }

  /// Get move details
  Future<PokemonMoveDetail> getMoveDetail(
    String moveId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'move_$moveId';

    try {
      // Check cache first
      if (!forceRefresh) {
        final cached = await _cache.get<Map<String, dynamic>>(cacheKey);
        if (cached != null) {
          return PokemonMoveDetail.fromJson(cached);
        }
      }

      final response = await _get('${ApiBaseUrls.pokeApi}/move/$moveId');
      final moveDetail = _mapMoveDetailResponse(response);

      // Cache result
      await _cache.put(cacheKey, moveDetail.toJson());

      return moveDetail;
    } catch (e) {
      _monitoring.logError(
        'Failed to fetch move detail',
        error: e,
        additionalData: {'moveId': moveId},
      );
      rethrow;
    }
  }

  /// Base GET request with retry logic
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

      // Handle rate limiting
      if (response.statusCode == 429 && retryCount < _maxRetries) {
        await Future.delayed(Duration(seconds: pow(2, retryCount).toInt()));
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

  /// Map Pokemon response to model
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

  /// Map Pokemon stats response
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

  /// Map Pokemon detail response
  Future<PokemonDetailModel> _mapPokemonDetailResponse({
    required Map<String, dynamic> pokemonData,
    required Map<String, dynamic> speciesData,
    required Map<String, dynamic> evolutionData,
  }) async {
    // Map basic Pokemon data
    final basicPokemon = _mapPokemonResponse(pokemonData);

    // Map abilities
    final abilities = await _mapAbilities(
      pokemonData['abilities'] as List<dynamic>,
    );

    // Map moves
    final moves = await _mapMoves(pokemonData['moves'] as List<dynamic>);

    // Map evolution chain
    final evolutionChain = await _mapEvolutionChain(
      evolutionData['chain'] as Map<String, dynamic>,
    );

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

  /// Map move detail response
  PokemonMoveDetail _mapMoveDetailResponse(Map<String, dynamic> data) {
    return PokemonMoveDetail(
      id: data['id'] as int,
      name: data['name'] as String,
      type: data['type']['name'] as String,
      category: _mapMoveCategory(data['damage_class']['name'] as String),
      power: data['power'] as int?,
      accuracy: data['accuracy'] as int?,
      pp: data['pp'] as int,
      priority: data['priority'] as int,
      effect: _getEnglishMoveEffect(data['effect_entries'] as List<dynamic>),
      shortEffect:
          _getEnglishMoveShortEffect(data['effect_entries'] as List<dynamic>),
      effectChance: data['effect_chance'] as int?,
      target: data['target']['name'] as String,
      critRate: data['meta']?['crit_rate'] as int? ?? 0,
      drainPercentage: data['meta']?['drain'] as int?,
      healPercentage: data['meta']?['healing'] as int?,
      maxHits: data['meta']?['max_hits'] as int?,
      minHits: data['meta']?['min_hits'] as int?,
      maxTurns: data['meta']?['max_turns'] as int?,
      minTurns: data['meta']?['min_turns'] as int?,
      statChanges: _mapStatChanges(data['stat_changes'] as List<dynamic>),
      flags: _mapMoveFlags(data['flags'] as Map<String, dynamic>),
    );
  }

  /// Map move category
  MoveCategory _mapMoveCategory(String category) {
    switch (category) {
      case 'physical':
        return MoveCategory.physical;
      case 'special':
        return MoveCategory.special;
      case 'status':
        return MoveCategory.status;
      default:
        return MoveCategory.status;
    }
  }

  /// Map stat changes
  List<MoveStatChange> _mapStatChanges(List<dynamic> changes) {
    return changes
        .map((change) => MoveStatChange(
              stat: change['stat']['name'] as String,
              change: change['change'] as int,
            ))
        .toList();
  }

  /// Map move flags
  List<MoveFlag> _mapMoveFlags(Map<String, dynamic> flags) {
    return flags.entries
        .where((e) => e.value == true)
        .map((e) => MoveFlag(
              name: e.key,
              description: _getFlagDescription(e.key),
            ))
        .toList();
  }

  /// Get English move effect
  String _getEnglishMoveEffect(List<dynamic> effects) {
    return effects.firstWhere(
      (e) => e['language']['name'] == 'en',
      orElse: () => {'effect': 'No description available.'},
    )['effect'] as String;
  }

  /// Get English move short effect
  String _getEnglishMoveShortEffect(List<dynamic> effects) {
    return effects.firstWhere(
      (e) => e['language']['name'] == 'en',
      orElse: () => {'short_effect': 'No description available.'},
    )['short_effect'] as String;
  }

  /// Get English description
  String _getEnglishDescription(List<dynamic> entries) {
    final entry = entries.firstWhere(
      (e) => e['language']['name'] == 'en',
      orElse: () => {'flavor_text': 'No description available.'},
    );
    return (entry['flavor_text'] as String)
        .replaceAll('\n', ' ')
        .replaceAll('\f', ' ')
        .trim();
  }

  /// Get move flag description
  String _getFlagDescription(String flag) {
    switch (flag) {
      case 'contact':
        return 'Makes contact with the target';
      case 'charge':
        return 'Requires charging turn';
      case 'recharge':
        return 'Requires recharge turn';
      case 'protect':
        return 'Can be blocked by Protect';
      case 'reflectable':
        return 'Can be reflected by Magic Coat';
      case 'snatch':
        return 'Can be stolen by Snatch';
      case 'mirror':
        return 'Can be reflected by Mirror Move';
      case 'punch':
        return 'Punch-based move';
      case 'sound':
        return 'Sound-based move';
      case 'gravity':
        return 'Disabled by Gravity';
      case 'defrost':
        return 'Can defrost frozen Pokemon';
      case 'distance':
        return 'Can target any Pokemon in Triple Battles';
      case 'heal':
        return 'Blocked by Heal Block';
      case 'authentic':
        return 'Ignores a target\'s substitute';
      default:
        return 'No description available';
    }
  }

  /// Map abilities with details
  Future<List<PokemonAbility>> _mapAbilities(List<dynamic> abilities) async {
    final mappedAbilities = <PokemonAbility>[];

    for (final ability in abilities) {
      final abilityUrl = ability['ability']['url'] as String;
      final abilityData = await _get(abilityUrl);

      final description = _getEnglishAbilityEffect(
        abilityData['effect_entries'] as List<dynamic>,
      );

      mappedAbilities.add(PokemonAbility(
        name: ability['ability']['name'] as String,
        description: description,
        isHidden: ability['is_hidden'] as bool,
      ));
    }

    return mappedAbilities;
  }

  /// Get English ability effect
  String _getEnglishAbilityEffect(List<dynamic> effects) {
    return effects.firstWhere(
      (e) => e['language']['name'] == 'en',
      orElse: () => {'effect': 'No description available.'},
    )['effect'] as String;
  }

  /// Map evolution chain
  Future<List<EvolutionStage>> _mapEvolutionChain(
    Map<String, dynamic> chain,
  ) async {
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

      final firstEvolution = details.isNotEmpty ? details[0] : null;

      stages.add(EvolutionStage(
        pokemonId: pokemonId,
        name: species['name'] as String,
        spriteUrl: spriteUrl,
        level: firstEvolution?['min_level'] as int?,
        trigger: firstEvolution?['trigger']?['name'] as String?,
        item: firstEvolution?['item']?['name'] as String?,
      ));

      for (final evolution in evolvesTo) {
        await processChain(evolution as Map<String, dynamic>);
      }
    }

    await processChain(chain);
    return stages;
  }

  /// Map moves with basic info
  Future<List<PokemonMove>> _mapMoves(List<dynamic> moves) async {
    final mappedMoves = <PokemonMove>[];

    for (final move in moves) {
      final moveUrl = move['move']['url'] as String;
      final moveData = await _get(moveUrl);

      mappedMoves.add(PokemonMove(
        name: moveData['name'] as String,
        type: moveData['type']['name'] as String,
        power: moveData['power'] as int?,
        accuracy: moveData['accuracy'] as int?,
        pp: moveData['pp'] as int,
        description: _getEnglishMoveEffect(
          moveData['effect_entries'] as List<dynamic>,
        ),
      ));
    }

    return mappedMoves;
  }

  /// Clear cache
  Future<void> clearCache() => _cache.clear();

  /// Dispose resources
  void dispose() {
    _client.close();
    if (kDebugMode) {
      print('🧹 API Service disposed');
    }
  }

  /// Helper method to check API status
  Future<bool> checkApiStatus() async {
    try {
      final response = await _client
          .get(Uri.parse(ApiBaseUrls.pokeApi))
          .timeout(_defaultTimeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
