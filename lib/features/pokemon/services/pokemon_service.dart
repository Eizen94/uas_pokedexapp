// lib/features/pokemon/services/pokemon_service.dart

import 'dart:async';
import 'package:synchronized/synchronized.dart';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/cache_manager.dart';
import '../../../core/utils/connectivity_manager.dart';
import '../../../core/utils/monitoring_manager.dart';
import '../../../core/constants/api_paths.dart';
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
  late final ConnectivityManager _connectivityManager;
  late final MonitoringManager _monitoringManager;
  late final CacheManager _cacheManager;
  bool _isInitialized = false;

  PokemonService._();

  /// Initialize service as singleton
  static Future<PokemonService> initialize() async {
    if (_instance != null) {
      return _instance!;
    }

    return await _initLock.synchronized(() async {
      if (_instance != null) {
        return _instance!;
      }

      final service = PokemonService._();
      await service._init();
      _instance = service;
      return _instance!;
    });
  }

  /// Initialize dependencies
  Future<void> _init() async {
    if (_isInitialized) return;

    _apiHelper = ApiHelper();
    await _apiHelper.initialize();

    _connectivityManager = ConnectivityManager();
    _monitoringManager = MonitoringManager();
    _cacheManager = await CacheManager.initialize();

    _isInitialized = true;
  }

  /// Fetch Pokemon list with pagination
  Future<List<PokemonModel>> getPokemonList({
    int limit = 20,
    int offset = 0,
  }) async {
    if (!_isInitialized) throw StateError('PokemonService not initialized');

    try {
      if (!_connectivityManager.hasConnection) {
        final cachedData = await _getCachedPokemonList(limit, offset);
        if (cachedData != null) return cachedData;
        throw PokemonServiceError.networkError;
      }

      final cacheKey = CacheKeys.pokemonList(limit, offset);
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached
            .map((item) => PokemonModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

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
          pokemonList.add(PokemonModel.fromJson(detailResponse.data!));
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

  /// Get detailed Pokemon information
  Future<PokemonDetailModel> getPokemonDetail(int id) async {
    if (!_isInitialized) throw StateError('PokemonService not initialized');

    try {
      final cacheKey = CacheKeys.pokemonDetails(id);
      final cached = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return PokemonDetailModel.fromJson(cached);
      }

      if (!_connectivityManager.hasConnection) {
        throw PokemonServiceError.networkError;
      }

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

      await _cacheManager.put(cacheKey, detail.toJson());
      return detail;
    } catch (e) {
      _monitoringManager.logError(
        'Failed to fetch Pokemon detail',
        error: e,
        additionalData: {'pokemonId': id},
      );
      rethrow;
    }
  }

  Future<List<PokemonModel>?> _getCachedPokemonList(
    int limit,
    int offset,
  ) async {
    final cacheKey = CacheKeys.pokemonList(limit, offset);
    final cached = await _cacheManager.get<List<dynamic>>(cacheKey);

    return cached
        ?.map((item) => PokemonModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _cachePokemonList(
    int limit,
    int offset,
    List<PokemonModel> pokemonList,
  ) async {
    final cacheKey = CacheKeys.pokemonList(limit, offset);
    await _cacheManager.put(
      cacheKey,
      pokemonList.map((p) => p.toJson()).toList(),
    );
  }

  Future<PokemonDetailModel> _buildPokemonDetail({
    required Map<String, dynamic> pokemonData,
    required Map<String, dynamic> speciesData,
    Map<String, dynamic>? evolutionData,
  }) async {
    final types = (pokemonData['types'] as List<dynamic>)
        .map((t) => t['type']['name'] as String)
        .toList();

    final stats = PokemonStats(
      hp: _getStat(pokemonData['stats'] as List<dynamic>, 'hp'),
      attack: _getStat(pokemonData['stats'] as List<dynamic>, 'attack'),
      defense: _getStat(pokemonData['stats'] as List<dynamic>, 'defense'),
      specialAttack:
          _getStat(pokemonData['stats'] as List<dynamic>, 'special-attack'),
      specialDefense:
          _getStat(pokemonData['stats'] as List<dynamic>, 'special-defense'),
      speed: _getStat(pokemonData['stats'] as List<dynamic>, 'speed'),
    );

    final abilities =
        await _mapAbilities(pokemonData['abilities'] as List<dynamic>);
    final moves = await _mapMoves(pokemonData['moves'] as List<dynamic>);

    List<EvolutionStage> evolutionChain = [];
    if (evolutionData != null) {
      evolutionChain = await _mapEvolutionChain(
          evolutionData['chain'] as Map<String, dynamic>);
    }

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
      species: _getEnglishGenus(speciesData['genera'] as List<dynamic>),
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

  int _getStat(List<dynamic> stats, String name) {
    return (stats.firstWhere(
          (stat) => stat['stat']['name'] == name,
          orElse: () => {'base_stat': 0},
        )['base_stat'] as int?) ??
        0;
  }

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

      final response = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: ApiPaths.pokemonDetails(pokemonId),
        parser: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final spriteUrl = response.data!['sprites']['other']['official-artwork']
                ['front_default'] as String? ??
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
    }

    await processChain(chain);
    return stages;
  }

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

  String _getEnglishGenus(List<dynamic> genera) {
    return genera.firstWhere(
      (g) => g['language']['name'] == 'en',
      orElse: () => {'genus': 'Unknown'},
    )['genus'] as String;
  }

  /// Clear all Pokemon related cache
  Future<void> clearCache() async {
    await _cacheManager.clear();
  }
}
