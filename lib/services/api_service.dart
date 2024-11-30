// lib/providers/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class PokeApiService {
  // Base URL untuk PokeAPI
  static const String baseUrl = 'https://pokeapi.co/api/v2';

  // Cache untuk menyimpan response API
  final Map<String, dynamic> _cache = {};

  // Singleton pattern
  static final PokeApiService _instance = PokeApiService._internal();
  factory PokeApiService() => _instance;
  PokeApiService._internal();

  // Method helper untuk GET request dengan caching
  Future<Map<String, dynamic>> _getRequest(String endpoint) async {
    // Cek cache dulu
    if (_cache.containsKey(endpoint)) {
      return _cache[endpoint];
    }

    try {
      final response = await http.get(Uri.parse('$baseUrl$endpoint'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _cache[endpoint] = data; // Simpan ke cache
        return data;
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  // Mengambil daftar Pokemon dengan pagination
  Future<Map<String, dynamic>> getPokemonList(
      {int offset = 0, int limit = 20}) async {
    return _getRequest('/pokemon?offset=$offset&limit=$limit');
  }

  // Mengambil detail Pokemon berdasarkan ID atau nama
  Future<Map<String, dynamic>> getPokemonDetail(String idOrName) async {
    return _getRequest('/pokemon/$idOrName');
  }

  // Mengambil evolution chain berdasarkan ID
  Future<Map<String, dynamic>> getEvolutionChain(int id) async {
    return _getRequest('/evolution-chain/$id');
  }

  // Mengambil informasi species Pokemon
  Future<Map<String, dynamic>> getPokemonSpecies(String idOrName) async {
    return _getRequest('/pokemon-species/$idOrName');
  }

  // Mengambil informasi type Pokemon
  Future<Map<String, dynamic>> getTypeInfo(String type) async {
    return _getRequest('/type/$type');
  }

  // Mengambil informasi ability Pokemon
  Future<Map<String, dynamic>> getAbilityInfo(String ability) async {
    return _getRequest('/ability/$ability');
  }

  // Method untuk membersihkan cache
  void clearCache() {
    _cache.clear();
  }

  // Method untuk mengecek status API
  Future<bool> checkApiStatus() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Helper untuk mendapatkan URL gambar Pokemon official artwork
  String getOfficialArtwork(int pokemonId) {
    return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$pokemonId.png';
  }

  // Helper untuk mendapatkan URL sprite Pokemon
  String getPokemonSprite(int pokemonId) {
    return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$pokemonId.png';
  }
}
