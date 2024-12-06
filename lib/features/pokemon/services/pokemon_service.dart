// lib/features/pokemon/services/pokemon_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/pokemon_model.dart';
import '../models/pokemon_detail_model.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/request_manager.dart';

class PokemonService {
  static const String baseUrl = 'https://pokeapi.co/api/v2';
  final ApiHelper _apiHelper = ApiHelper();
  bool _hasInitialized = false;

  // Request tracking
  final Map<String, CancellationToken> _activeTokens = {};

  // Singleton pattern
  static final PokemonService _instance = PokemonService._internal();
  factory PokemonService() => _instance;
  PokemonService._internal();

  Future<void> initialize() async {
    if (!_hasInitialized) {
      await _apiHelper.initialize();
      _hasInitialized = true;
    }
  }

  Future<List<PokemonModel>> getPokemonList({
    int offset = 0,
    int limit = 20,
    CancellationToken? cancellationToken,
  }) async {
    try {
      if (kDebugMode) {
        print('📥 Fetching Pokemon list: offset=$offset, limit=$limit');
      }

      await initialize();

      final requestToken = cancellationToken ?? CancellationToken();
      _activeTokens['pokemon_list_$offset'] = requestToken;

      final response = await _apiHelper.get<List<PokemonModel>>(
        '$baseUrl/pokemon?offset=$offset&limit=$limit',
        cancellationToken: requestToken,
        parser: (data) {
          final List<dynamic> results = data['results'] as List<dynamic>;
          final List<PokemonModel> pokemonList = [];

          for (var pokemon in results) {
            if (pokemon is Map<String, dynamic> && pokemon['url'] != null) {
              final detailData =
                  _fetchPokemonDetail(pokemon['url'] as String, requestToken);
              if (detailData != null) {
                pokemonList.add(PokemonModel.fromJson(detailData));
              }
            }
          }

          pokemonList.sort((a, b) => a.id.compareTo(b.id));
          return pokemonList;
        },
      );

      if (response.isCancelled) {
        throw const RequestCancelledException();
      }

      if (response.isSuccess && response.data != null) {
        final pokemonList = response.data!;
        if (kDebugMode) {
          print('✅ Successfully fetched ${pokemonList.length} Pokemon');
        }
        return pokemonList;
      }

      throw response.error ?? 'Failed to load pokemon list';
    } on RequestCancelledException {
      if (kDebugMode) {
        print('🚫 Pokemon list request cancelled');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting pokemon list: $e');
      }
      throw _handleError(e);
    } finally {
      _activeTokens.remove('pokemon_list_$offset');
    }
  }

  Future<PokemonDetailModel> getPokemonDetail(
    String idOrName, {
    CancellationToken? cancellationToken,
  }) async {
    try {
      if (kDebugMode) {
        print('📥 Fetching Pokemon detail: $idOrName');
      }

      await initialize();

      final requestToken = cancellationToken ?? CancellationToken();
      _activeTokens['pokemon_detail_$idOrName'] = requestToken;

      // Get base Pokemon data
      final response = await _apiHelper.get<Map<String, dynamic>>(
        '$baseUrl/pokemon/$idOrName',
        cancellationToken: requestToken,
        parser: (data) => data,
      );

      if (response.isCancelled) {
        throw const RequestCancelledException();
      }

      if (!response.isSuccess || response.data == null) {
        throw response.error ?? 'Failed to load pokemon detail';
      }

      final pokemonData = response.data!;
      final speciesUrl = pokemonData['species']['url'] as String;

      // Fetch species data
      final speciesResponse = await _apiHelper.get<Map<String, dynamic>>(
        speciesUrl,
        cancellationToken: requestToken,
        parser: (data) => data,
      );

      if (speciesResponse.isCancelled) {
        throw const RequestCancelledException();
      }

      if (!speciesResponse.isSuccess || speciesResponse.data == null) {
        throw speciesResponse.error ?? 'Failed to load species data';
      }

      final speciesData = speciesResponse.data!;

      // Get evolution chain if available
      if (speciesData['evolution_chain']?['url'] != null) {
        final evolutionChain = await _getEvolutionChain(
          speciesData['evolution_chain']['url'] as String,
          requestToken,
        );
        pokemonData['evolution'] = evolutionChain;
      } else {
        pokemonData['evolution'] = null;
      }

      // Create Pokemon detail model
      final pokemon = PokemonDetailModel.fromJson(pokemonData);

      if (kDebugMode) {
        print('✅ Successfully fetched Pokemon detail: ${pokemon.name}');
      }

      return pokemon;
    } on RequestCancelledException {
      if (kDebugMode) {
        print('🚫 Pokemon detail request cancelled');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting pokemon detail: $e');
      }
      throw _handleError(e);
    } finally {
      _activeTokens.remove('pokemon_detail_$idOrName');
    }
  }

  Map<String, dynamic>? _fetchPokemonDetail(
    String url,
    CancellationToken token,
  ) {
    try {
      final response = _apiHelper.get<Map<String, dynamic>>(
        url,
        cancellationToken: token,
        parser: (data) => data,
      );

      if (response is ApiResponse<Map<String, dynamic>> &&
          response.isSuccess &&
          response.data != null) {
        return response.data;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Warning: Failed to fetch individual Pokemon: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>> _getEvolutionChain(
    String url,
    CancellationToken token,
  ) async {
    try {
      final response = await _apiHelper.get<Map<String, dynamic>>(
        url,
        cancellationToken: token,
        parser: (data) {
          final chain = data['chain'] as Map<String, dynamic>?;
          return _parseEvolutionChain(chain);
        },
      );

      if (response.isCancelled) {
        throw const RequestCancelledException();
      }

      if (response.isSuccess && response.data != null) {
        return response.data!;
      }

      throw response.error ?? 'Failed to load evolution chain';
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

  Map<String, dynamic> _parseEvolutionChain(Map<String, dynamic>? chain) {
    if (chain == null) {
      return {
        'chain_id': 0,
        'stages': <Map<String, dynamic>>[],
      };
    }

    final List<Map<String, dynamic>> stages = [];
    Map<String, dynamic>? current = chain;

    while (current != null) {
      final speciesData = current['species'] as Map<String, dynamic>?;
      if (speciesData == null) break;

      final speciesUrl = speciesData['url'] as String;
      final pokemonId = int.parse(speciesUrl.split('/')[6]);

      stages.add({
        'pokemon_id': pokemonId,
        'name': speciesData['name'] as String? ?? 'unknown',
        'min_level': (current['evolution_details'] as List?)?.isEmpty ?? true
            ? 1
            : ((current['evolution_details'] as List).first
                    as Map<String, dynamic>)['min_level'] as int? ??
                1,
      });

      final evolvesTo = current['evolves_to'] as List?;
      current = evolvesTo?.isNotEmpty == true
          ? evolvesTo!.first as Map<String, dynamic>?
          : null;
    }

    return {
      'chain_id': int.parse(chain['species']['url'].split('/')[6]),
      'stages': stages,
    };
  }

  Exception _handleError(dynamic error) {
    if (error is TimeoutException) {
      return TimeoutException('Connection timeout: Please check your internet');
    } else if (error is HttpException) {
      return HttpException('Network error: ${error.message}');
    } else if (error is FormatException) {
      return FormatException('Data format error: Please try again later');
    } else if (error is RequestCancelledException) {
      return error;
    } else {
      return Exception('An unexpected error occurred: ${error.toString()}');
    }
  }

  // Cancel specific request
  void cancelRequest(String identifier) {
    final token = _activeTokens[identifier];
    if (token != null) {
      token.cancel();
      _activeTokens.remove(identifier);
    }
  }

  // Cancel all active requests
  void cancelAllRequests() {
    for (final token in _activeTokens.values) {
      token.cancel();
    }
    _activeTokens.clear();
    _apiHelper.cancelAllRequests();
  }

  void dispose() {
    cancelAllRequests();
    _hasInitialized = false;
  }
}
