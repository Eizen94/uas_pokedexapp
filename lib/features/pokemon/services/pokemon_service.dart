// lib/features/pokemon/services/pokemon_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

import '../../../core/constants/api_paths.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/monitoring_manager.dart';
import '../models/pokemon_model.dart';
import '../models/pokemon_detail_model.dart';

/// Pokemon service error messages
class PokemonServiceError {
  static const String notFound = 'Pokemon not found';
  static const String fetchError = 'Failed to fetch Pokemon data';
  static const String networkError = 'Network error occurred';
  static const String cacheError = 'Cache error occurred';
}

/// Service class for Pokemon operations
class PokemonService {
  static PokemonService? _instance;
  static final _initLock = Lock();

  late final ApiHelper _apiHelper;
  late final MonitoringManager _monitoringManager;
  bool _isInitialized = false;

  PokemonService._();

  /// Initialize service as singleton
  static Future<PokemonService> initialize() async {
    if (_instance != null) return _instance!;

    return await _initLock.synchronized(() async {
      if (_instance != null) return _instance!;

      try {
        debugPrint('🎮 PokemonService: Starting initialization...');
        final service = PokemonService._();

        service._monitoringManager = MonitoringManager();
        service._apiHelper = ApiHelper();

        debugPrint('🎮 PokemonService: Initializing API helper...');
        await service._apiHelper.initialize();

        service._isInitialized = true;
        _instance = service;
        debugPrint('✅ PokemonService initialized');
        return _instance!;
      } catch (e, stack) {
        debugPrint('❌ PokemonService initialization failed: $e');
        debugPrint(stack.toString());
        rethrow;
      }
    });
  }

  /// Fetch Pokemon list with pagination
  Future<List<PokemonModel>> getPokemonList({
    int limit = 20,
    int offset = 0,
  }) async {
    if (!_isInitialized) throw StateError('PokemonService not initialized');

    try {
      debugPrint('🎮 PokemonService: Fetching Pokemon list...');

      final response = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: ApiPaths.pokemonList(limit, offset),
        parser: (json) => json,
      );

      if (!response.isSuccess || response.data == null) {
        throw PokemonServiceError.fetchError;
      }

      final results = response.data!['results'] as List<dynamic>;
      final pokemonList = <PokemonModel>[];

      for (final item in results) {
        final detailResponse = await _apiHelper.get<Map<String, dynamic>>(
          endpoint: item['url'] as String,
          parser: (json) => json,
        );

        if (detailResponse.isSuccess && detailResponse.data != null) {
          pokemonList.add(_mapPokemonResponse(detailResponse.data!));
        }
      }

      debugPrint('✅ PokemonService: Fetched ${pokemonList.length} Pokemon');
      return pokemonList;
    } catch (e, stack) {
      debugPrint('❌ PokemonService: Failed to fetch Pokemon list: $e');
      _monitoringManager.logError(
        'Failed to fetch Pokemon list',
        error: e,
        stackTrace: stack,
        additionalData: {'limit': limit, 'offset': offset},
      );
      rethrow;
    }
  }

  /// Get detailed Pokemon information
  Future<PokemonDetailModel> getPokemonDetail(int id) async {
    if (!_isInitialized) throw StateError('PokemonService not initialized');

    try {
      debugPrint('🎮 PokemonService: Fetching Pokemon detail for ID: $id');

      final response = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: ApiPaths.pokemonDetails(id),
        parser: (json) => json,
      );

      if (!response.isSuccess || response.data == null) {
        throw PokemonServiceError.notFound;
      }

      final pokemonData = response.data!;
      final speciesUrl = pokemonData['species']['url'] as String;

      final speciesResponse = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: speciesUrl,
        parser: (json) => json,
      );

      if (!speciesResponse.isSuccess || speciesResponse.data == null) {
        throw PokemonServiceError.fetchError;
      }

      final speciesData = speciesResponse.data!;
      final evolutionUrl = speciesData['evolution_chain']['url'] as String;

      final evolutionResponse = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: evolutionUrl,
        parser: (json) => json,
      );

      final detail = await _buildPokemonDetail(
        pokemonData: pokemonData,
        speciesData: speciesData,
        evolutionData:
            evolutionResponse.isSuccess ? evolutionResponse.data : null,
      );

      debugPrint('✅ PokemonService: Fetched details for ${detail.name}');
      return detail;
    } catch (e, stack) {
      debugPrint('❌ PokemonService: Failed to fetch Pokemon detail: $e');
      _monitoringManager.logError(
        'Failed to fetch Pokemon detail',
        error: e,
        stackTrace: stack,
        additionalData: {'pokemonId': id},
      );
      rethrow;
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
      return (stats.firstWhere(
            (s) => s['stat']['name'] == name,
            orElse: () => {'base_stat': 0},
          )['base_stat'] as int?) ??
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
    Map<String, dynamic>? evolutionData,
  }) async {
    final basicPokemon = _mapPokemonResponse(pokemonData);
    final abilities =
        await _mapAbilities(pokemonData['abilities'] as List<dynamic>);
    final moves = await _mapMoves(pokemonData['moves'] as List<dynamic>);

    // Fix type casting here
    List<EvolutionStage> evolutionChain = [];
    if (evolutionData != null) {
      evolutionChain = await _mapEvolutionChain(
          evolutionData['chain'] as Map<String, dynamic>);
    }

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
      evolutionChain: evolutionChain, // Now with proper type
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
      final response = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: ability['ability']['url'] as String,
        parser: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final effectEntries = response.data!['effect_entries'] as List<dynamic>;
        final description = effectEntries.firstWhere(
          (entry) => entry['language']['name'] == 'en',
          orElse: () => {'effect': 'No description available'},
        )['effect'] as String;

        mappedAbilities.add(PokemonAbility(
          name: ability['ability']['name'] as String,
          description: description,
          isHidden: ability['is_hidden'] as bool,
        ));
      }
    }

    return mappedAbilities;
  }

  /// Map Pokemon moves with full details
  Future<List<PokemonMove>> _mapMoves(List<dynamic> moves) async {
    final mappedMoves = <PokemonMove>[];

    for (final move in moves) {
      final response = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: move['move']['url'] as String,
        parser: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final effectEntries = response.data!['effect_entries'] as List<dynamic>;
        final description = effectEntries.firstWhere(
          (entry) => entry['language']['name'] == 'en',
          orElse: () => {'effect': 'No description available'},
        )['effect'] as String;

        mappedMoves.add(PokemonMove(
          name: move['move']['name'] as String,
          type: response.data!['type']['name'] as String,
          power: response.data!['power'] as int?,
          accuracy: response.data!['accuracy'] as int?,
          pp: response.data!['pp'] as int? ?? 0,
          description: description,
        ));
      }
    }

    return mappedMoves;
  }

  /// Map evolution chain data
  Future<List<EvolutionStage>> _mapEvolutionChain(
      Map<String, dynamic> chain) async {
    final stages = <EvolutionStage>[];

    Future<void> processChain(Map<String, dynamic> currentChain) async {
      try {
        final species = currentChain['species'] as Map<String, dynamic>;
        final evolvesTo = currentChain['evolves_to'] as List<dynamic>;
        final details = currentChain['evolution_details'] as List<dynamic>;

        final pokemonId = int.parse(
          (species['url'] as String).split('/')[6],
        );

        final response = await _apiHelper.get<Map<String, dynamic>>(
          endpoint: ApiPaths.pokemonDetails(pokemonId),
          parser: (json) => json,
        );

        if (response.isSuccess && response.data != null) {
          final spriteUrl = response.data!['sprites']['other']
                  ['official-artwork']['front_default'] as String? ??
              response.data!['sprites']['front_default'] as String;

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

          for (final evolution in evolvesTo) {
            await processChain(evolution as Map<String, dynamic>);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error processing evolution chain: $e');
      }
    }

    await processChain(chain);
    return stages;
  }

  /// Get English description from flavor text entries
  String _getEnglishDescription(List<dynamic> entries) {
    final entry = entries.firstWhere(
      (entry) => entry['language']['name'] == 'en',
      orElse: () => {'flavor_text': 'No description available'},
    );

    return ((entry['flavor_text'] as String?) ?? 'No description available')
        .replaceAll('\n', ' ')
        .replaceAll('\f', ' ')
        .trim();
  }

  /// Clear service cache
  Future<void> clearCache() async {
    await _apiHelper.initialize();
  }
}
