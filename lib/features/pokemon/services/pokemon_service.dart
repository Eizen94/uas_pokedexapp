// lib/features/pokemon/services/pokemon_service.dart

/// Pokemon service to handle Pokemon data operations.
/// Manages Pokemon data fetching, caching, and processing.
library features.pokemon.services.pokemon_service;

import 'dart:async';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/cache_manager.dart';
import '../../../core/utils/connectivity_manager.dart';
import '../../../core/utils/monitoring_manager.dart';
import '../../../core/constants/api_paths.dart';
import '../models/pokemon_model.dart';
import '../models/pokemon_detail_model.dart';
import '../models/pokemon_move_model.dart';

/// Error messages for Pokemon service
class PokemonServiceError {
  static const String notFound = 'Pokemon not found';
  static const String fetchError = 'Failed to fetch Pokemon data';
  static const String networkError = 'Network error occurred';
  static const String cacheError = 'Cache error occurred';
}

/// Service class for Pokemon operations
class PokemonService {
  final ApiHelper _apiHelper;
  final CacheManager _cacheManager;
  final ConnectivityManager _connectivityManager;
  final MonitoringManager _monitoringManager;

  /// Constructor
  const PokemonService({
    ApiHelper? apiHelper,
    CacheManager? cacheManager,
    ConnectivityManager? connectivityManager,
    MonitoringManager? monitoringManager,
  }) : _apiHelper = apiHelper ?? ApiHelper(),
       _cacheManager = cacheManager ?? CacheManager(),
       _connectivityManager = connectivityManager ?? ConnectivityManager(),
       _monitoringManager = monitoringManager ?? MonitoringManager();

  /// Fetch Pokemon list with pagination
  Future<List<PokemonModel>> getPokemonList({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Check cache first
      final cacheKey = CacheKeys.pokemonList(limit, offset);
      final cachedData = await _cacheManager.get<List<dynamic>>(cacheKey);
      
      if (cachedData != null) {
        return cachedData
            .map((item) => PokemonModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      // Fetch from API if not in cache
      final response = await _apiHelper.get<Map<String, dynamic>>(
        url: ApiPaths.pokemonList(limit, offset),
      );

      final List<dynamic> results = response['results'] as List<dynamic>;
      final pokemonList = await Future.wait(
        results.map((item) => _fetchPokemonData(item['url'] as String)),
      );

      // Cache the results
      await _cacheManager.put(cacheKey, pokemonList.map((p) => p.toJson()).toList());

      return pokemonList;
    } catch (e) {
      _monitoringManager.logError(
        'Failed to fetch Pokemon list',
        error: e,
        additionalData: {'limit': limit, 'offset': offset},
      );
      throw PokemonServiceError.fetchError;
    }
  }

  /// Fetch Pokemon detail by ID
  Future<PokemonDetailModel> getPokemonDetail(int id) async {
    try {
      // Check cache first
      final cacheKey = CacheKeys.pokemonDetails(id);
      final cachedData = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
      
      if (cachedData != null) {
        return PokemonDetailModel.fromJson(cachedData);
      }

      // Fetch basic Pokemon data
      final pokemonData = await _apiHelper.get<Map<String, dynamic>>(
        url: ApiPaths.pokemonDetails(id),
      );

      // Fetch species data
      final speciesData = await _apiHelper.get<Map<String, dynamic>>(
        url: ApiPaths.pokemonSpecies(id),
      );

      // Fetch evolution chain
      final evolutionUrl = speciesData['evolution_chain']['url'] as String;
      final evolutionData = await _apiHelper.get<Map<String, dynamic>>(
        url: evolutionUrl,
      );

      // Combine all data
      final detailModel = await _combinePokemonData(
        pokemonData,
        speciesData,
        evolutionData,
      );

      // Cache the result
      await _cacheManager.put(cacheKey, detailModel.toJson());

      return detailModel;
    } catch (e) {
      _monitoringManager.logError(
        'Failed to fetch Pokemon detail',
        error: e,
        additionalData: {'pokemonId': id},
      );
      throw PokemonServiceError.fetchError;
    }
  }

  /// Fetch Pokemon move details
  Future<PokemonMoveDetail> getMoveDetail(String moveName) async {
    try {
      final cacheKey = 'move_$moveName';
      final cachedData = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
      
      if (cachedData != null) {
        return PokemonMoveDetail.fromJson(cachedData);
      }

      final response = await _apiHelper.get<Map<String, dynamic>>(
        url: '${ApiBaseUrls.pokeApi}/move/${_formatMoveName(moveName)}',
      );

      final moveDetail = PokemonMoveDetail.fromJson(response);
      await _cacheManager.put(cacheKey, moveDetail.toJson());

      return moveDetail;
    } catch (e) {
      _monitoringManager.logError(
        'Failed to fetch move detail',
        error: e,
        additionalData: {'moveName': moveName},
      );
      throw PokemonServiceError.fetchError;
    }
  }

  /// Format move name for API
  String _formatMoveName(String name) {
    return name.toLowerCase().replaceAll(' ', '-');
  }

  /// Fetch basic Pokemon data
  Future<PokemonModel> _fetchPokemonData(String url) async {
    final response = await _apiHelper.get<Map<String, dynamic>>(url: url);
    return PokemonModel.fromJson(response);
  }

  /// Combine all Pokemon data into detail model
  Future<PokemonDetailModel> _combinePokemonData(
    Map<String, dynamic> pokemonData,
    Map<String, dynamic> speciesData,
    Map<String, dynamic> evolutionData,
  ) async {
    // Extract basic data
    final baseModel = PokemonModel.fromJson(pokemonData);

    // Extract abilities
    final abilities = (pokemonData['abilities'] as List<dynamic>)
        .map((ability) => PokemonAbility(
              name: ability['ability']['name'] as String,
              description: '', // Will be fetched separately if needed
              isHidden: ability['is_hidden'] as bool,
            ))
        .toList();

    // Extract moves
    final moves = (pokemonData['moves'] as List<dynamic>)
        .map((move) => PokemonMove(
              name: move['move']['name'] as String,
              type: '', // Will be fetched separately if needed
              power: null,
              accuracy: null,
              pp: 0,
              description: '',
            ))
        .toList();

    // Extract evolution chain
    final evolutionStages = _extractEvolutionChain(evolutionData['chain']);

    // Extract species data
    final descriptions = speciesData['flavor_text_entries'] as List<dynamic>;
    final description = descriptions
        .firstWhere(
          (entry) => (entry['language']['name'] as String) == 'en',
          orElse: () => {'flavor_text': ''},
        )['flavor_text'] as String;

    return PokemonDetailModel(
      id: baseModel.id,
      name: baseModel.name,
      types: baseModel.types,
      spriteUrl: baseModel.spriteUrl,
      stats: baseModel.stats,
      height: baseModel.height,
      weight: baseModel.weight,
      baseExperience: baseModel.baseExperience,
      species: baseModel.species,
      abilities: abilities,
      moves: moves,
      evolutionChain: evolutionStages,
      description: description.replaceAll('\n', ' ').replaceAll('\f', ' '),
      catchRate: speciesData['capture_rate'] as int,
      eggGroups: (speciesData['egg_groups'] as List<dynamic>)
          .map((group) => group['name'] as String)
          .toList(),
      genderRatio: speciesData['gender_rate'] as int * 12.5,
      generation: int.parse((speciesData['generation']['url'] as String)
          .split('/')
          .reversed
          .skip(1)
          .first),
      habitat: (speciesData['habitat'] ?? {'name': 'unknown'})['name'] as String,
    );
  }

  /// Extract evolution chain data
  List<EvolutionStage> _extractEvolutionChain(Map<String, dynamic> chain) {
    final List<EvolutionStage> stages = [];
    
    void processChain(Map<String, dynamic> current) {
      final species = current['species'];
      final evolutionDetails = current['evolution_details'];
      final evolvesTo = current['evolves_to'] as List<dynamic>;

      stages.add(EvolutionStage(
        pokemonId: int.parse(species['url'].toString().split('/').reversed.skip(1).first),
        name: species['name'] as String,
        spriteUrl: '', // Will be updated with proper sprite URL
        level: evolutionDetails.isNotEmpty ? evolutionDetails[0]['min_level'] as int? : null,
        trigger: evolutionDetails.isNotEmpty ? evolutionDetails[0]['trigger']['name'] as String : null,
        item: evolutionDetails.isNotEmpty && evolutionDetails[0]['item'] != null
            ? evolutionDetails[0]['item']['name'] as String
            : null,
      ));

      for (final evolution in evolvesTo) {
        processChain(evolution as Map<String, dynamic>);
      }
    }

    processChain(chain);
    return stages;
  }
}