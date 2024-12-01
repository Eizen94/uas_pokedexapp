// lib/features/pokemon/services/pokemon_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/pokemon_model.dart';
import '../models/pokemon_detail_model.dart';
import '../../../core/utils/api_helper.dart';

class PokemonService {
  static const String baseUrl = 'https://pokeapi.co/api/v2';
  final http.Client _client = http.Client();
  final Map<String, dynamic> _cache = {};
  final Duration _cacheDuration = const Duration(hours: 24);
  final Map<String, DateTime> _cacheTimestamps = {};

  // Singleton pattern
  static final PokemonService _instance = PokemonService._internal();
  factory PokemonService() => _instance;
  PokemonService._internal();

  Future<List<PokemonModel>> getPokemonList({
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      if (kDebugMode) {
        print('📥 Fetching Pokemon list: offset=$offset, limit=$limit');
      }

      final cacheKey = 'pokemon_list_${offset}_$limit';

      // Check cache first
      if (_hasValidCache(cacheKey)) {
        if (kDebugMode) {
          print('🗂️ Using cached Pokemon list data');
        }
        return _getCachedPokemonList(cacheKey);
      }

      final response = await _client
          .get(
        Uri.parse('$baseUrl/pokemon?offset=$offset&limit=$limit'),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Connection timeout. Please check your internet.');
        },
      );

      if (response.statusCode != 200) {
        throw HttpException('Failed to load pokemon list');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final List<dynamic> results = data['results'] as List<dynamic>;
      final List<PokemonModel> pokemonList = [];
      final List<Future<void>> futures = [];

      for (var pokemon in results) {
        if (pokemon is Map<String, dynamic> && pokemon['url'] != null) {
          futures.add(
              _fetchPokemonDetail(pokemon['url'] as String).then((detailData) {
            if (detailData != null) {
              try {
                pokemonList.add(PokemonModel.fromJson(detailData));
              } catch (e) {
                if (kDebugMode) {
                  print('⚠️ Error parsing Pokemon data: $e');
                }
              }
            }
          }));
        }
      }

      await Future.wait(futures);

      // Sort by ID to maintain consistent order
      pokemonList.sort((a, b) => a.id.compareTo(b.id));

      // Cache the results
      _cache[cacheKey] = pokemonList.map((p) => p.toJson()).toList();
      _cacheTimestamps[cacheKey] = DateTime.now();

      if (kDebugMode) {
        print('✅ Successfully fetched ${pokemonList.length} Pokemon');
      }

      return pokemonList;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting pokemon list: $e');
      }
      throw _handleError(e);
    }
  }

  Future<PokemonDetailModel> getPokemonDetail(String idOrName) async {
    try {
      if (kDebugMode) {
        print('📥 Fetching Pokemon detail: $idOrName');
      }

      final cacheKey = 'pokemon_detail_$idOrName';

      // Check cache first
      if (_hasValidCache(cacheKey)) {
        if (kDebugMode) {
          print('🗂️ Using cached Pokemon detail data');
        }
        return PokemonDetailModel.fromJson(
            _cache[cacheKey] as Map<String, dynamic>);
      }

      final response = await _client
          .get(
        Uri.parse('$baseUrl/pokemon/$idOrName'),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
              'Connection timeout. Please check your internet.');
        },
      );

      if (response.statusCode != 200) {
        throw HttpException('Failed to load pokemon detail');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      // Fetch species data
      final speciesUrl = data['species']['url'] as String;
      final speciesResponse = await _client.get(Uri.parse(speciesUrl));

      if (speciesResponse.statusCode == 200) {
        final speciesData =
            json.decode(speciesResponse.body) as Map<String, dynamic>;
        if (speciesData['evolution_chain']?['url'] != null) {
          // Fetch evolution chain
          data['evolution'] = await _getEvolutionChain(
            speciesData['evolution_chain']['url'] as String,
          );
        } else {
          data['evolution'] = null;
        }
      }

      // Cache the data
      _cache[cacheKey] = data;
      _cacheTimestamps[cacheKey] = DateTime.now();

      if (kDebugMode) {
        print('✅ Successfully fetched Pokemon detail: ${data['name']}');
      }

      return PokemonDetailModel.fromJson(data);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting pokemon detail: $e');
      }
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>?> _fetchPokemonDetail(String url) async {
    try {
      final response = await _client.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Warning: Failed to fetch individual Pokemon: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>> _getEvolutionChain(String url) async {
    try {
      final cacheKey = 'evolution_${url.split('/').last}';

      if (_hasValidCache(cacheKey)) {
        return _cache[cacheKey] as Map<String, dynamic>;
      }

      final response = await _client.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        throw HttpException('Failed to load evolution chain');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final evolutionData =
          _parseEvolutionChain(data['chain'] as Map<String, dynamic>);

      _cache[cacheKey] = evolutionData;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return evolutionData;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Warning: Evolution chain fetch failed: $e');
      }
      return {
        'chain_id': 0,
        'stages': <Map<String, dynamic>>[],
      };
    }
  }

  Map<String, dynamic> _parseEvolutionChain(Map<String, dynamic> chain) {
    final List<Map<String, dynamic>> stages = [];
    var current = chain;

    while (current != null) {
      final speciesUrl = current['species']['url'] as String;
      final pokemonId = int.parse(speciesUrl.split('/')[6]);

      stages.add({
        'pokemon_id': pokemonId,
        'name': current['species']['name'],
        'min_level': (current['evolution_details'] as List).isEmpty
            ? 1
            : (current['evolution_details'][0]['min_level'] ?? 1),
      });

      current = (current['evolves_to'] as List).isEmpty
          ? null
          : current['evolves_to'][0] as Map<String, dynamic>;
    }

    return {
      'chain_id': int.parse(chain['species']['url'].split('/')[6]),
      'stages': stages,
    };
  }

  bool _hasValidCache(String key) {
    if (!_cache.containsKey(key) || !_cacheTimestamps.containsKey(key)) {
      return false;
    }

    final timestamp = _cacheTimestamps[key]!;
    return DateTime.now().difference(timestamp) < _cacheDuration;
  }

  List<PokemonModel> _getCachedPokemonList(String key) {
    final List<dynamic> cachedData = _cache[key] as List<dynamic>;
    return cachedData
        .map((item) => PokemonModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Exception _handleError(dynamic e) {
    if (e is TimeoutException) {
      return Exception('Connection timeout: Please check your internet');
    } else if (e is HttpException) {
      return Exception('Network error: ${e.message}');
    } else if (e is FormatException) {
      return Exception('Data format error: Please try again later');
    } else {
      return Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  // Clear specific cache entry
  void clearCache(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
  }

  // Clear all cache
  void clearAllCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  // Dispose resources
  void dispose() {
    _client.close();
    clearAllCache();
  }
}
