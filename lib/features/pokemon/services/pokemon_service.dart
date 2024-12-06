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

      final response = await _apiHelper.get(
        '$baseUrl/pokemon?offset=$offset&limit=$limit',
        cancellationToken: requestToken,
        parser: (data) async {
          final List<dynamic> results = data['results'] as List<dynamic>;
          final List<PokemonModel> pokemonList = [];
          final List<Future<void>> futures = [];

          for (var pokemon in results) {
            if (pokemon is Map<String, dynamic> && pokemon['url'] != null) {
              futures.add(
                _fetchPokemonDetail(pokemon['url'] as String, requestToken)
                    .then((detailData) {
                  if (detailData != null) {
                    pokemonList.add(PokemonModel.fromJson(detailData));
                  }
                }),
              );
            }
          }

          await Future.wait(futures);
          pokemonList.sort((a, b) => a.id.compareTo(b.id));
          return pokemonList;
        },
      );

      if (response.isCancelled) {
        throw const RequestCancelledException();
      }

      if (response.isSuccess && response.data != null) {
        if (kDebugMode) {
          print('✅ Successfully fetched ${response.data!.length} Pokemon');
        }
        return response.data!;
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

      final response = await _apiHelper.get(
        '$baseUrl/pokemon/$idOrName',
        cancellationToken: requestToken,
        parser: (data) async {
          // Fetch species data
          final speciesUrl = data['species']['url'] as String;
          final speciesResponse = await _apiHelper.get(
            speciesUrl,
            cancellationToken: requestToken,
            parser: (speciesData) async {
              if (speciesData['evolution_chain']?['url'] != null) {
                // Fetch evolution chain
                data['evolution'] = await _getEvolutionChain(
                  speciesData['evolution_chain']['url'] as String,
                  requestToken,
                );
              } else {
                data['evolution'] = null;
              }
              return data;
            },
          );

          if (speciesResponse.isCancelled) {
            throw const RequestCancelledException();
          }

          if (speciesResponse.isSuccess && speciesResponse.data != null) {
            return PokemonDetailModel.fromJson(speciesResponse.data!);
          }

          throw speciesResponse.error ?? 'Failed to load species data';
        },
      );

      if (response.isCancelled) {
        throw const RequestCancelledException();
      }

      if (response.isSuccess && response.data != null) {
        if (kDebugMode) {
          print(
              '✅ Successfully fetched Pokemon detail: ${response.data!.name}');
        }
        return response.data!;
      }

      throw response.error ?? 'Failed to load pokemon detail';
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

  Future<Map<String, dynamic>?> _fetchPokemonDetail(
    String url,
    CancellationToken token,
  ) async {
    try {
      final response = await _apiHelper.get(
        url,
        cancellationToken: token,
        parser: (data) => data,
      );

      if (response.isCancelled) return null;

      if (response.isSuccess) {
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
      final response = await _apiHelper.get(
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
        return response.data;
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
