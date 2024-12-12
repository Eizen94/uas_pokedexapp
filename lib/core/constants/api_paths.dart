// lib/core/constants/api_paths.dart

import 'dart:core';
import 'package:flutter/foundation.dart';

/// Complete API path management system with validation and organization.
/// Handles all endpoint paths, rate limits, and resource locations.
class ApiPaths {
  // API Configuration
  static const String kApiVersion = 'v2';
  static const String kBaseUrl = 'https://pokeapi.co/api/$kApiVersion';
  static const String kSpritesBaseUrl =
      'https://raw.githubusercontent.com/PokeAPI/sprites/master';
  static const String kSoundBaseUrl =
      'https://play.pokemonshowdown.com/audio/cries';

  // Rate Limits
  static const int publicApiLimit = 100; // Requests per minute
  static const Duration rateLimitWindow = Duration(minutes: 1);
  static const Duration minRequestDelay = Duration(milliseconds: 100);

  // Core Pokemon Endpoints
  static const String kPokemon = '/pokemon';
  static const String kPokemonSpecies = '/pokemon-species';
  static const String kEvolutionChain = '/evolution-chain';
  static const String kMove = '/move';
  static const String kAbility = '/ability';
  static const String kType = '/type';
  static const String kItem = '/item';
  static const String kLocation = '/location';
  static const String kNature = '/nature';

  // Cache Settings
  static const Duration defaultCacheExpiry = Duration(hours: 24);
  static const int maxCacheSize = 5 * 1024 * 1024; // 5MB
  static const int cacheItemLimit = 1000;

  // Request Settings
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  static const int maxConcurrentRequests = 5;
  static const int batchSize = 20;

  // Media Paths
  static const String defaultSpritePath = '/sprites/pokemon';
  static const String officialArtworkPath =
      '/sprites/pokemon/other/official-artwork';
  static const String shinySpritePath = '/sprites/pokemon/shiny';

  /// Generate Pokemon detail endpoint
  /// Returns full URL for Pokemon data
  static String getPokemonEndpoint(String idOrName) {
    assert(idOrName.isNotEmpty, 'Pokemon ID or name cannot be empty');
    return '$kBaseUrl$kPokemon/$idOrName';
  }

  /// Generate species endpoint
  /// Returns full URL for Pokemon species data
  static String getPokemonSpeciesEndpoint(String idOrName) {
    assert(idOrName.isNotEmpty, 'Pokemon ID or name cannot be empty');
    return '$kBaseUrl$kPokemonSpecies/$idOrName';
  }

  /// Generate evolution chain endpoint
  /// Returns full URL for evolution chain data
  static String getEvolutionChainEndpoint(int id) {
    assert(id > 0, 'Evolution chain ID must be positive');
    return '$kBaseUrl$kEvolutionChain/$id';
  }

  /// Generate move endpoint
  /// Returns full URL for move data
  static String getMoveEndpoint(String idOrName) {
    assert(idOrName.isNotEmpty, 'Move ID or name cannot be empty');
    return '$kBaseUrl$kMove/$idOrName';
  }

  /// Generate ability endpoint
  /// Returns full URL for ability data
  static String getAbilityEndpoint(String idOrName) {
    assert(idOrName.isNotEmpty, 'Ability ID or name cannot be empty');
    return '$kBaseUrl$kAbility/$idOrName';
  }

  /// Generate type endpoint
  /// Returns full URL for type data
  static String getTypeEndpoint(String type) {
    assert(type.isNotEmpty, 'Type cannot be empty');
    return '$kBaseUrl$kType/$type';
  }

  /// Generate sprite URL
  /// Returns full URL for Pokemon sprite
  static String getSpriteUrl(int pokemonId, {bool shiny = false}) {
    assert(pokemonId > 0, 'Pokemon ID must be positive');
    final path = shiny ? shinySpritePath : defaultSpritePath;
    return '$kSpritesBaseUrl$path/$pokemonId.png';
  }

  /// Generate official artwork URL
  /// Returns full URL for Pokemon official artwork
  static String getOfficialArtwork(int pokemonId) {
    assert(pokemonId > 0, 'Pokemon ID must be positive');
    return '$kSpritesBaseUrl$officialArtworkPath/$pokemonId.png';
  }

  /// Generate cry sound URL
  /// Returns full URL for Pokemon cry sound
  static String getPokemonCry(int pokemonId) {
    assert(pokemonId > 0, 'Pokemon ID must be positive');
    return '$kSoundBaseUrl/$pokemonId.mp3';
  }

  /// Generate list endpoint with pagination
  /// Returns full URL for paginated Pokemon list
  static String getListEndpoint({int offset = 0, int limit = batchSize}) {
    assert(offset >= 0, 'Offset cannot be negative');
    assert(limit > 0 && limit <= 100, 'Limit must be between 1 and 100');
    return '$kBaseUrl$kPokemon?offset=$offset&limit=$limit';
  }

  /// Generate search endpoint
  /// Returns full URL for Pokemon search
  static String getSearchEndpoint(String query) {
    assert(query.isNotEmpty, 'Search query cannot be empty');
    return '$kBaseUrl$kPokemon/$query';
  }

  /// Validate URL string
  /// Returns true if URL is valid
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute;
    } catch (e) {
      if (kDebugMode) {
        print('Invalid URL: $url');
      }
      return false;
    }
  }

  /// Generate cache key for endpoint
  /// Returns unique cache key for given endpoint
  static String generateCacheKey(String endpoint) {
    assert(endpoint.isNotEmpty, 'Endpoint cannot be empty');
    return 'cache_${endpoint.hashCode}';
  }

  /// Error & Fallback Assets
  static const String kErrorImage = 'assets/images/error_pokemon.png';
  static const String kPlaceholderImage =
      'assets/images/placeholder_pokemon.png';
  static const String kLoadingImage = 'assets/images/loading_pokemon.gif';

  /// Private constructor to prevent instantiation
  const ApiPaths._();
}
