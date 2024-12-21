// lib/features/pokemon/services/pokemon_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/constants/api_paths.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/monitoring_manager.dart';
import '../../../core/utils/connectivity_manager.dart';
import '../../../core/utils/cache_manager.dart';
import '../../../core/utils/rate_limiter.dart';
import '../models/pokemon_model.dart';
import '../models/pokemon_detail_model.dart';

/// Pokemon service errors
class PokemonServiceError implements Exception {
  final String message;
  final dynamic originalError;

  const PokemonServiceError({
    required this.message,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Pokemon service for handling API requests and caching
class PokemonService {
  // Singleton implementation with proper synchronization
  static final PokemonService _instance = PokemonService._internal();
  factory PokemonService() => _instance;
  PokemonService._internal();

  // Dependencies
  late final ApiHelper _apiHelper;
  late final CacheManager _cacheManager;
  late final MonitoringManager _monitoringManager;
  late final ConnectivityManager _connectivityManager;
  late final RateLimiter _rateLimiter;

  // State
  bool _isInitialized = false;
  bool _isDisposed = false;

  /// Initialize service as singleton
  static Future<PokemonService> initialize() async {
    if (_instance._isInitialized) {
      return _instance;
    }

    try {
      debugPrint('🎮 PokemonService: Starting initialization...');

      _instance._monitoringManager = MonitoringManager();
      _instance._connectivityManager = ConnectivityManager();
      _instance._rateLimiter = RateLimiter();

      // Initialize cache manager
      _instance._cacheManager = await CacheManager.initialize();

      // Initialize API helper with cache manager
      _instance._apiHelper = ApiHelper();
      await _instance._apiHelper.initialize();

      _instance._isInitialized = true;
      debugPrint('✅ PokemonService initialized');

      return _instance;
    } catch (e, stack) {
      debugPrint('❌ PokemonService initialization failed: $e');
      debugPrint(stack.toString());
      _instance._monitoringManager.logError(
        'PokemonService initialization failed',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Get Pokemon list with pagination and caching
  Future<List<PokemonModel>> getPokemonList({
    int offset = 0,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    _verifyState();

    try {
      debugPrint('🎮 PokemonService: Fetching Pokemon list...');

      // Check rate limit
      await _rateLimiter.checkRateLimit();

      // Handle offline mode
      if (!_connectivityManager.hasConnection && !forceRefresh) {
        final cached = await _getCachedPokemonList(offset, limit);
        if (cached != null) return cached;
        throw const PokemonServiceError(message: 'No internet connection');
      }

      // Get Pokemon list
      final response = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: ApiPaths.pokemonList(limit, offset),
        parser: (json) => json,
      );

      if (!response.isSuccess || response.data == null) {
        throw PokemonServiceError(
            message: response.message ?? 'Failed to fetch Pokemon list');
      }

      // Parse response
      final results = response.data!['results'] as List<dynamic>;
      final pokemonList = <PokemonModel>[];

      for (final item in results) {
        final url = item['url'] as String;
        if (url.isEmpty) continue;

        final detailResponse = await _apiHelper.get<Map<String, dynamic>>(
          endpoint: url,
          parser: (json) => json,
        );

        if (detailResponse.isSuccess && detailResponse.data != null) {
          final pokemon = _mapPokemonResponse(detailResponse.data!);
          if (pokemon != null) {
            pokemonList.add(pokemon);
          }
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
        additionalData: {'offset': offset, 'limit': limit},
      );
      throw PokemonServiceError(
        message: 'Failed to fetch Pokemon list: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Get detailed Pokemon information by ID
  Future<PokemonDetailModel> getPokemonDetail(int id) async {
    _verifyState();

    try {
      // Check rate limit
      await _rateLimiter.checkRateLimit();

      final cacheKey = 'pokemon_detail_$id';

      // Try cache first
      final cached = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return PokemonDetailModel.fromJson(cached);
      }

      // Fetch from API
      final response = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: ApiPaths.pokemonDetails(id),
        parser: (json) => json,
      );

      if (!response.isSuccess || response.data == null) {
        throw PokemonServiceError(
            message: response.message ?? 'Failed to fetch Pokemon detail');
      }

      // Get species data
      final speciesUrl = response.data!['species']['url'] as String;
      final speciesResponse = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: speciesUrl,
        parser: (json) => json,
      );

      if (!speciesResponse.isSuccess || speciesResponse.data == null) {
        throw const PokemonServiceError(
            message: 'Failed to fetch species data');
      }

      // Get evolution data
      final evolutionUrl =
          speciesResponse.data!['evolution_chain']['url'] as String;
      final evolutionResponse = await _apiHelper.get<Map<String, dynamic>>(
        endpoint: evolutionUrl,
        parser: (json) => json,
      );

      // Build complete model
      final detail = await _buildPokemonDetail(
        pokemonData: response.data!,
        speciesData: speciesResponse.data!,
        evolutionData:
            evolutionResponse.isSuccess ? evolutionResponse.data : null,
      );

      // Cache result
      await _cacheManager.put(cacheKey, detail.toJson());

      return detail;
    } catch (e, stack) {
      _monitoringManager.logError(
        'Failed to fetch Pokemon detail',
        error: e,
        stackTrace: stack,
        additionalData: {'pokemonId': id},
      );
      throw PokemonServiceError(
        message: 'Failed to fetch Pokemon detail: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Get cached Pokemon list
  Future<List<PokemonModel>?> _getCachedPokemonList(
      int offset, int limit) async {
    try {
      final cacheKey = 'pokemon_list_${offset}_$limit';
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);

      if (cached == null) return null;

      return cached
          .map((json) => PokemonModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Cache read error: $e');
      return null;
    }
  }

  /// Map Pokemon response to model
  PokemonModel? _mapPokemonResponse(Map<String, dynamic> data) {
    try {
      final types = (data['types'] as List<dynamic>)
          .map((t) => t['type']['name'] as String)
          .toList();

      final stats = _mapPokemonStats(data['stats'] as List<dynamic>);

      final spriteUrl = data['sprites']['other']['official-artwork']
              ['front_default'] as String? ??
          data['sprites']['front_default'] as String? ??
          '';

      if (spriteUrl.isEmpty) return null;

      return PokemonModel(
        id: data['id'] as int,
        name: data['name'] as String,
        types: types,
        spriteUrl: spriteUrl,
        stats: stats,
        height: data['height'] as int,
        weight: data['weight'] as int,
        baseExperience: data['base_experience'] as int? ?? 0,
        species: data['species']['name'] as String,
      );
    } catch (e) {
      debugPrint('Error mapping Pokemon response: $e');
      return null;
    }
  }

  /// Map Pokemon stats from API response
  PokemonStats _mapPokemonStats(List<dynamic> stats) {
    int getStat(String name) {
      try {
        return stats.firstWhere(
              (s) => s['stat']['name'] == name,
              orElse: () => {'base_stat': 0},
            )['base_stat'] as int? ??
            0;
      } catch (e) {
        debugPrint('Error getting stat $name: $e');
        return 0;
      }
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
    try {
      final basicPokemon = _mapPokemonResponse(pokemonData);
      if (basicPokemon == null) {
        throw const PokemonServiceError(message: 'Failed to map Pokemon data');
      }

      final abilities =
          await _mapAbilities(pokemonData['abilities'] as List<dynamic>);
      final moves = await _mapMoves(pokemonData['moves'] as List<dynamic>);
      final evolutionChain = evolutionData != null
          ? await _mapEvolutionChain(
              evolutionData['chain'] as Map<String, dynamic>)
          : [];

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
        generation: int.parse(
            (speciesData['generation']['url'] as String).split('/')[6]),
        habitat: (speciesData['habitat'] as Map<String, dynamic>?)?['name']
                as String? ??
            'unknown',
      );
    } catch (e) {
      throw PokemonServiceError(
        message: 'Error building Pokemon detail: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Map Pokemon abilities with details
  Future<List<PokemonAbility>> _mapAbilities(List<dynamic> abilities) async {
    final mappedAbilities = <PokemonAbility>[];

    for (final ability in abilities) {
      try {
        final abilityUrl = ability['ability']['url'] as String;
        final response = await _apiHelper.get<Map<String, dynamic>>(
          endpoint: abilityUrl,
          parser: (json) => json,
        );

        if (response.isSuccess && response.data != null) {
          final effectEntries =
              response.data!['effect_entries'] as List<dynamic>;
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
      } catch (e) {
        debugPrint('Error mapping ability: $e');
        continue;
      }
    }

    return mappedAbilities;
  }

  /// Map Pokemon moves with details
  Future<List<PokemonMove>> _mapMoves(List<dynamic> moves) async {
    final mappedMoves = <PokemonMove>[];

    for (final move in moves) {
      try {
        final moveUrl = move['move']['url'] as String;
        final response = await _apiHelper.get<Map<String, dynamic>>(
          endpoint: moveUrl,
          parser: (json) => json,
        );

        if (response.isSuccess && response.data != null) {
          final effectEntries =
              response.data!['effect_entries'] as List<dynamic>;
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
      } catch (e) {
        debugPrint('Error mapping move: $e');
        continue;
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

        // Extract Pokemon ID from species URL
        final pokemonId = int.parse(
          (species['url'] as String).split('/')[6],
        );

        // Get Pokemon data for sprite URL
        final response = await _apiHelper.get<Map<String, dynamic>>(
          endpoint: ApiPaths.pokemonDetails(pokemonId),
          parser: (json) => json,
        );

        if (response.isSuccess && response.data != null) {
          final spriteUrl = response.data!['sprites']['other']
                  ['official-artwork']['front_default'] as String? ??
              response.data!['sprites']['front_default'] as String? ??
              '';

          if (spriteUrl.isNotEmpty) {
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
          }

          // Process next evolution stage recursively
          for (final evolution in evolvesTo) {
            await processChain(evolution as Map<String, dynamic>);
          }
        }
      } catch (e) {
        debugPrint('Error processing evolution chain: $e');
      }
    }

    await processChain(chain);
    return stages;
  }

  /// Get English description from flavor text entries
  String _getEnglishDescription(List<dynamic> entries) {
    try {
      final entry = entries.firstWhere(
        (entry) => entry['language']['name'] == 'en',
        orElse: () => {'flavor_text': 'No description available'},
      );

      final text =
          (entry['flavor_text'] as String?) ?? 'No description available';
      return text.replaceAll('\n', ' ').replaceAll('\f', ' ').trim();
    } catch (e) {
      debugPrint('Error getting description: $e');
      return 'No description available';
    }
  }

  /// Verify service state
  void _verifyState() {
    if (_isDisposed) {
      throw StateError('PokemonService has been disposed');
    }
    if (!_isInitialized) {
      throw StateError('PokemonService not initialized');
    }
  }

  /// Clear service cache
  Future<void> clearCache() async {
    _verifyState();
    await _cacheManager.clear();
  }

  /// Clean up resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    await clearCache();
    _apiHelper.dispose();
    _isDisposed = true;
    _isInitialized = false;
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if service is disposed
  bool get isDisposed => _isDisposed;
}
