// lib/features/pokemon/services/pokemon_service.dart

/// Pokemon service to handle Pokemon data operations.
/// Manages Pokemon data fetching, caching, and processing.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/cache_manager.dart';
import '../../../core/utils/connectivity_manager.dart';
import '../../../core/utils/monitoring_manager.dart';
import '../../../core/constants/api_paths.dart';
import '../models/pokemon_model.dart';
import '../models/pokemon_detail_model.dart';
import '../models/pokemon_move_model.dart';

/// Pokemon service error messages
class PokemonServiceError {
  static const String notFound = 'Pokemon not found';
  static const String fetchError = 'Failed to fetch Pokemon data';
  static const String networkError = 'Network error occurred';
  static const String cacheError = 'Cache error occurred';
}

/// Service class for Pokemon operations
class PokemonService {
  final ApiHelper _apiHelper;
  final ConnectivityManager _connectivityManager;
  final MonitoringManager _monitoringManager;
  late final CacheManager _cacheManager;

  PokemonService._({
    required ApiHelper apiHelper,
    required ConnectivityManager connectivityManager,
    required MonitoringManager monitoringManager,
  })  : _apiHelper = apiHelper,
        _connectivityManager = connectivityManager,
        _monitoringManager = monitoringManager;

  static Future<PokemonService> initialize() async {
    final service = PokemonService._(
      apiHelper: ApiHelper(),
      connectivityManager: ConnectivityManager(),
      monitoringManager: MonitoringManager(),
    );
    service._cacheManager = await CacheManager.initialize();
    return service;
  }

  /// Fetch Pokemon list with pagination
  Future<List<PokemonModel>> getPokemonList({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (!_connectivityManager.hasConnection) {
        final cachedData = await _getCachedPokemonList(limit, offset);
        if (cachedData != null) return cachedData;
        throw PokemonServiceError.networkError;
      }

      final response = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: ApiPaths.pokemonList(limit, offset),
        parser: (json) => json,
      );

      final data = response.data;
      if (data == null) throw PokemonServiceError.fetchError;

      final results = data['results'] as List<dynamic>?;
      if (results == null) throw PokemonServiceError.fetchError;

      final List<PokemonModel> pokemonList = [];

      for (final item in results) {
        final pokemonResponse = await _apiHelper.get<Map<String, dynamic>>(
          endpoint: item['url'] as String,
          parser: (json) => json,
        );

        final pokemonData = pokemonResponse.data;
        if (pokemonData != null) {
          pokemonList.add(PokemonModel.fromJson(pokemonData));
        }
      }

      await _cachePokemonList(limit, offset, pokemonList);
      return pokemonList;
    } catch (e) {
      _monitoringManager.logError(
        'Failed to fetch Pokemon list',
        error: e,
        additionalData: {'limit': limit, 'offset': offset},
      );
      rethrow;
    }
  }

  /// Fetch Pokemon detail by ID
  Future<PokemonDetailModel> getPokemonDetail(int id) async {
    try {
      if (!_connectivityManager.hasConnection) {
        final cachedDetail = await _getCachedPokemonDetail(id);
        if (cachedDetail != null) return cachedDetail;
        throw PokemonServiceError.networkError;
      }

      final pokemonResponse = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: ApiPaths.pokemonDetails(id),
        parser: (json) => json,
      );

      final pokemonData = pokemonResponse.data;
      if (pokemonData == null) throw PokemonServiceError.notFound;

      final speciesUrl = pokemonData['species']['url'] as String;
      final speciesResponse = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: speciesUrl,
        parser: (json) => json,
      );

      final speciesData = speciesResponse.data;
      if (speciesData == null) throw PokemonServiceError.fetchError;

      final evolutionUrl = speciesData['evolution_chain']['url'] as String;
      final evolutionResponse = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: evolutionUrl,
        parser: (json) => json,
      );

      final evolutionData = evolutionResponse.data;
      if (evolutionData == null) throw PokemonServiceError.fetchError;

      final detailModel = await _buildPokemonDetail(
        pokemonData: pokemonData,
        speciesData: speciesData,
        evolutionData: evolutionData,
      );

      await _cachePokemonDetail(id, detailModel);
      return detailModel;
    } catch (e) {
      _monitoringManager.logError(
        'Failed to fetch Pokemon detail',
        error: e,
        additionalData: {'pokemonId': id},
      );
      rethrow;
    }
  }

  /// Build Pokemon detail model from API responses
  Future<PokemonDetailModel> _buildPokemonDetail({
    required Map<String, dynamic> pokemonData,
    required Map<String, dynamic> speciesData,
    required Map<String, dynamic> evolutionData,
  }) async {
    final types = (pokemonData['types'] as List<dynamic>)
        .map((type) => type['type']['name'] as String)
        .toList();

    final stats = PokemonStats(
      hp: _getStat(pokemonData['stats'], 'hp'),
      attack: _getStat(pokemonData['stats'], 'attack'),
      defense: _getStat(pokemonData['stats'], 'defense'),
      specialAttack: _getStat(pokemonData['stats'], 'special-attack'),
      specialDefense: _getStat(pokemonData['stats'], 'special-defense'),
      speed: _getStat(pokemonData['stats'], 'speed'),
    );

    final abilities =
        await _buildAbilities(pokemonData['abilities'] as List<dynamic>);
    final moves = await _buildMoves(pokemonData['moves'] as List<dynamic>);
    final evolutionChain = await _buildEvolutionChain(
        evolutionData['chain'] as Map<String, dynamic>);
    final description = _getEnglishDescription(
        speciesData['flavor_text_entries'] as List<dynamic>);

    final habitat = speciesData['habitat'] as Map<String, dynamic>?;
    final habitatName = habitat?['name'] as String? ?? 'unknown';

    return PokemonDetailModel(
      id: pokemonData['id'] as int,
      name: pokemonData['name'] as String,
      types: types,
      spriteUrl: pokemonData['sprites']['other']['official-artwork']
              ['front_default'] as String? ??
          pokemonData['sprites']['front_default'] as String,
      stats: stats,
      height: pokemonData['height'] as int,
      weight: pokemonData['weight'] as int,
      baseExperience: pokemonData['base_experience'] as int? ?? 0,
      species: speciesData['genera'].firstWhere(
        (g) => g['language']['name'] == 'en',
        orElse: () => {'genus': 'Unknown'},
      )['genus'] as String,
      abilities: abilities,
      moves: moves,
      evolutionChain: evolutionChain,
      description: description,
      catchRate: speciesData['capture_rate'] as int,
      eggGroups: (speciesData['egg_groups'] as List<dynamic>)
          .map((g) => g['name'] as String)
          .toList(),
      genderRatio: (speciesData['gender_rate'] as int).toDouble() * 12.5,
      generation:
          int.parse((speciesData['generation']['url'] as String).split('/')[6]),
      habitat: habitatName,
    );
  }

  /// Get stat value from stats array
  int _getStat(List<dynamic> stats, String name) {
    return (stats.firstWhere(
          (stat) => stat['stat']['name'] == name,
          orElse: () => {'base_stat': 0},
        )['base_stat'] as int?) ??
        0;
  }

  /// Build abilities list with details
  Future<List<PokemonAbility>> _buildAbilities(
      List<dynamic> abilityData) async {
    final abilities = <PokemonAbility>[];

    for (final ability in abilityData) {
      final response = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: ability['ability']['url'] as String,
        parser: (json) => json,
      );

      final data = response.data;
      if (data != null) {
        final entries = data['effect_entries'] as List<dynamic>;
        final description = entries.firstWhere(
          (entry) => entry['language']['name'] == 'en',
          orElse: () => {'effect': 'No description available'},
        )['effect'] as String;

        abilities.add(PokemonAbility(
          name: ability['ability']['name'] as String,
          description: description,
          isHidden: ability['is_hidden'] as bool,
        ));
      }
    }

    return abilities;
  }

  /// Build moves list with details
  Future<List<PokemonMove>> _buildMoves(List<dynamic> moveData) async {
    final moves = <PokemonMove>[];

    for (final move in moveData) {
      final response = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: move['move']['url'] as String,
        parser: (json) => json,
      );

      final data = response.data;
      if (data != null) {
        final entries = data['effect_entries'] as List<dynamic>;
        final description = entries.firstWhere(
          (entry) => entry['language']['name'] == 'en',
          orElse: () => {'effect': 'No description available'},
        )['effect'] as String;

        moves.add(PokemonMove(
          name: move['move']['name'] as String,
          type: data['type']['name'] as String,
          power: data['power'] as int?,
          accuracy: data['accuracy'] as int?,
          pp: data['pp'] as int? ?? 0,
          description: description,
        ));
      }
    }

    return moves;
  }

  /// Build evolution chain list
  Future<List<EvolutionStage>> _buildEvolutionChain(
      Map<String, dynamic> chainData) async {
    final stages = <EvolutionStage>[];

    Future<void> processChain(Map<String, dynamic> chain) async {
      final species = chain['species'] as Map<String, dynamic>;
      final evolutionDetails = chain['evolution_details'] as List<dynamic>;
      final evolvesTo = chain['evolves_to'] as List<dynamic>;

      final pokemonId = int.parse(
        (species['url'] as String).split('/')[6],
      );

      final response = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: ApiPaths.pokemonDetails(pokemonId),
        parser: (json) => json,
      );

      final data = response.data;
      final spriteUrl = data?['sprites']['other']['official-artwork']
              ['front_default'] as String? ??
          data?['sprites']['front_default'] as String? ??
          '';

      final firstEvolution = evolutionDetails.isNotEmpty
          ? evolutionDetails[0] as Map<String, dynamic>
          : null;

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

    await processChain(chainData);
    return stages;
  }

  /// Get English description from flavor text entries
  String _getEnglishDescription(List<dynamic> flavorTextEntries) {
    final englishEntry = flavorTextEntries.firstWhere(
      (entry) => entry['language']['name'] == 'en',
      orElse: () => {'flavor_text': 'No description available'},
    );

    return ((englishEntry['flavor_text'] as String?) ??
            'No description available')
        .replaceAll('\n', ' ')
        .replaceAll('\f', ' ')
        .trim();
  }

  /// Cache related methods
  Future<void> _cachePokemonDetail(int id, PokemonDetailModel detail) async {
    final key = 'pokemon_detail_$id';
    await _cacheManager.put(key, detail.toJson());
  }

  Future<PokemonDetailModel?> _getCachedPokemonDetail(int id) async {
    final key = 'pokemon_detail_$id';
    final data = await _cacheManager.get<Map<String, dynamic>>(key);
    return data != null ? PokemonDetailModel.fromJson(data) : null;
  }

  Future<void> _cachePokemonList(
    int limit,
    int offset,
    List<PokemonModel> pokemonList,
  ) async {
    final key = 'pokemon_list_${limit}_$offset';
    await _cacheManager.put(key, pokemonList.map((p) => p.toJson()).toList());
  }

  Future<List<PokemonModel>?> _getCachedPokemonList(
    int limit,
    int offset,
  ) async {
    final key = 'pokemon_list_${limit}_$offset';
    final data = await _cacheManager.get<List<dynamic>>(key);

    return data
        ?.map((item) => PokemonModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Clear all Pokemon related cache
  Future<void> clearCache() async {
    await _cacheManager.clear();
  }
}
