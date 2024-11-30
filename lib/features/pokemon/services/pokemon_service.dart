// lib/features/pokemon/services/pokemon_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/pokemon_model.dart';
import '../models/pokemon_detail_model.dart';
import '../../../core/utils/api_helper.dart';

class PokemonService {
  static const String baseUrl = 'https://pokeapi.co/api/v2';
  final http.Client _client = http.Client();
  final Map<String, dynamic> _cache = {};

  Future<List<PokemonModel>> getPokemonList(
      {int offset = 0, int limit = 20}) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/pokemon?offset=$offset&limit=$limit'),
      );

      if (response.statusCode != 200) {
        throw ApiHelper.handleError('Failed to load pokemon list');
      }

      final data = json.decode(response.body);
      final List<PokemonModel> pokemonList = [];

      for (var pokemon in data['results']) {
        final detailResponse = await _client.get(Uri.parse(pokemon['url']));
        if (detailResponse.statusCode == 200) {
          final detailData = json.decode(detailResponse.body);
          pokemonList.add(PokemonModel.fromJson(detailData));
        }
      }

      return pokemonList;
    } catch (e) {
      throw ApiHelper.handleError('Error getting pokemon list: $e');
    }
  }

  Future<PokemonDetailModel> getPokemonDetail(String idOrName) async {
    try {
      if (_cache.containsKey(idOrName)) {
        return PokemonDetailModel.fromJson(_cache[idOrName]);
      }

      final response = await _client.get(
        Uri.parse('$baseUrl/pokemon/$idOrName'),
      );

      if (response.statusCode != 200) {
        throw ApiHelper.handleError('Failed to load pokemon detail');
      }

      final data = json.decode(response.body);

      final speciesResponse = await _client.get(
        Uri.parse(data['species']['url']),
      );

      if (speciesResponse.statusCode == 200) {
        final speciesData = json.decode(speciesResponse.body);
        data['evolution'] =
            await _getEvolutionChain(speciesData['evolution_chain']['url']);
      }

      _cache[idOrName] = data;
      return PokemonDetailModel.fromJson(data);
    } catch (e) {
      throw ApiHelper.handleError('Error getting pokemon detail: $e');
    }
  }

  Future<Map<String, dynamic>> _getEvolutionChain(String url) async {
    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw ApiHelper.handleError('Failed to load evolution chain');
      }

      final data = json.decode(response.body);
      return _parseEvolutionChain(data['chain']);
    } catch (e) {
      throw ApiHelper.handleError('Error getting evolution chain: $e');
    }
  }

  Map<String, dynamic> _parseEvolutionChain(Map<String, dynamic> chain) {
    List<Map<String, dynamic>> stages = [];
    var current = chain;

    while (current != null) {
      final speciesUrl = current['species']['url'];
      final pokemonId = int.parse(speciesUrl.split('/')[6]);

      stages.add({
        'pokemon_id': pokemonId,
        'name': current['species']['name'],
        'min_level': current['evolution_details']?.isEmpty == true
            ? 1
            : current['evolution_details'][0]['min_level'] ?? 1,
      });

      current = current['evolves_to']?.isEmpty == true
          ? null
          : current['evolves_to'][0];
    }

    return {
      'chain_id': int.parse(chain['species']['url'].split('/')[6]),
      'stages': stages,
    };
  }

  Future<void> clearCache() async {
    _cache.clear();
  }

  void dispose() {
    _client.close();
  }
}
