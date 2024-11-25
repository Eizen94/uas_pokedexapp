import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class ApiResponse<T> {
  final T? data;
  final String? error;
  final bool success;

  ApiResponse({
    this.data,
    this.error,
    required this.success,
  });
}

class ApiHelper {
  static const int timeoutDuration = 15; // dalam detik

  // Parse response JSON dengan error handling
  static ApiResponse<Map<String, dynamic>> parseResponse(
      http.Response response) {
    try {
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ApiResponse(data: data, success: true);
      }
      return ApiResponse(
        error: 'Error: ${response.statusCode}',
        success: false,
      );
    } catch (e) {
      return ApiResponse(
        error: 'Parse error: $e',
        success: false,
      );
    }
  }

  // Format URL dengan parameter
  static String formatUrl(
      String baseUrl, String endpoint, Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) return '$baseUrl$endpoint';

    final queryParams = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    return '$baseUrl$endpoint?$queryParams';
  }

  // Validasi Response
  static bool isValidResponse(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  // Extract ID dari URL Pokemon
  static int? extractPokemonId(String url) {
    final regex = RegExp(r'/(\d+)/?$');
    final match = regex.firstMatch(url);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  // Format nama Pokemon (Capitalize first letter)
  static String formatPokemonName(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1).toLowerCase();
  }

  // Convert height dari API (decimeters) ke meters
  static double convertHeight(int heightDm) {
    return heightDm / 10;
  }

  // Convert weight dari API (hectograms) ke kilograms
  static double convertWeight(int weightHg) {
    return weightHg / 10;
  }

  // Handle network errors
  static String handleError(dynamic error) {
    if (error is http.ClientException) {
      return 'Koneksi error: Periksa koneksi internet Anda';
    } else if (error is FormatException) {
      return 'Format data tidak valid';
    } else if (error is TimeoutException) {
      return 'Request timeout: Coba lagi nanti';
    }
    return 'Terjadi kesalahan: $error';
  }

  // Generate Image URL
  static String getPokemonImageUrl(int id) {
    return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';
  }

  // Get Pokemon type color
  static Map<String, String> pokemonTypeColors = {
    'normal': '#A8A878',
    'fire': '#F08030',
    'water': '#6890F0',
    'electric': '#F8D030',
    'grass': '#78C850',
    'ice': '#98D8D8',
    'fighting': '#C03028',
    'poison': '#A040A0',
    'ground': '#E0C068',
    'flying': '#A890F0',
    'psychic': '#F85888',
    'bug': '#A8B820',
    'rock': '#B8A038',
    'ghost': '#705898',
    'dragon': '#7038F8',
    'dark': '#705848',
    'steel': '#B8B8D0',
    'fairy': '#EE99AC',
  };

  // Get type effectiveness
  static double getTypeEffectiveness(
      String attackType, List<String> defenseTypes) {
    final effectiveness = {
      'normal': {'rock': 0.5, 'ghost': 0, 'steel': 0.5},
      'fire': {
        'fire': 0.5,
        'water': 0.5,
        'grass': 2,
        'ice': 2,
        'bug': 2,
        'rock': 0.5,
        'dragon': 0.5,
        'steel': 2
      },
      // Tambahkan type effectiveness lainnya sesuai kebutuhan
    };

    double multiplier = 1.0;
    for (var defenseType in defenseTypes) {
      final typeChart = effectiveness[attackType];
      if (typeChart != null && typeChart.containsKey(defenseType)) {
        multiplier *= typeChart[defenseType]!;
      }
    }
    return multiplier;
  }
}
