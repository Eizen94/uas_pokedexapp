// lib/core/constants/api_paths.dart

import 'dart:core';
import 'package:flutter/foundation.dart';

/// ApiPaths provides centralized API endpoint management with proper validation,
/// versioning, and organization. Implements complete path generation with
/// proper error handling and resource validation.
class ApiPaths {
  // API Configuration - Immutable constants
  static const String kApiVersion = 'v2';
  static const String kBaseUrl = 'https://pokeapi.co/api/$kApiVersion';
  static const String kSpritesBaseUrl =
      'https://raw.githubusercontent.com/PokeAPI/sprites/master';
  static const String kSoundBaseUrl =
      'https://play.pokemonshowdown.com/audio/cries';

  // Core Endpoints - Properly typed and immutable
  static const String kPokemon = '/pokemon';
  static const String kPokemonSpecies = '/pokemon-species';
  static const String kEvolutionChain = '/evolution-chain';
  static const String kMove = '/move';
  static const String kAbility = '/ability';
  static const String kType = '/type';
  static const String kItem = '/item';
  static const String kLocation = '/location';
  static const String kNature = '/nature';
  static const String kEggGroup = '/egg-group';

  // Firebase Collections - Properly scoped
  static const String kUsersCollection = 'users';
  static const String kFavoritesCollection = 'favorites';
  static const String kSettingsCollection = 'settings';
  static const String kCacheCollection = 'cache';

  // Cache Keys - Type safe and properly scoped
  static const String kPokemonListKey = 'pokemon_list';
  static const String kTypeChartKey = 'type_chart';
  static const String kAbilityListKey = 'ability_list';
  static const String kMoveListKey = 'move_list';
  static const String kItemListKey = 'item_list';
  static const String kLocationListKey = 'location_list';
  static const String kNatureListKey = 'nature_list';

  // API Limits & Timeouts - Properly typed durations
  static const Duration kRequestTimeout = Duration(seconds: 30);
  static const Duration kCacheExpiration = Duration(hours: 24);
  static const int kMaxRequestRetries = 3;
  static const int kMaxConcurrentRequests = 5;
  static const int kItemsPerPage = 20;
  static const int kMaxCacheSize = 5 * 1024 * 1024; // 5MB

  /// Get Pokemon detail endpoint with validation
  /// Throws [ArgumentError] if idOrName is empty
  static String getPokemonEndpoint(String idOrName) {
    _validateInput(idOrName, 'Pokemon ID or name');
    return '$kBaseUrl$kPokemon/$idOrName';
  }

  /// Get Pokemon species endpoint with validation
  /// Throws [ArgumentError] if idOrName is empty
  static String getPokemonSpeciesEndpoint(String idOrName) {
    _validateInput(idOrName, 'Pokemon ID or name');
    return '$kBaseUrl$kPokemonSpecies/$idOrName';
  }

  /// Get evolution chain endpoint with validation
  /// Throws [ArgumentError] if id is not positive
  static String getEvolutionChainEndpoint(int id) {
    _validateId(id, 'Evolution chain ID');
    return '$kBaseUrl$kEvolutionChain/$id';
  }

  /// Get move endpoint with validation
  /// Throws [ArgumentError] if idOrName is empty
  static String getMoveEndpoint(String idOrName) {
    _validateInput(idOrName, 'Move ID or name');
    return '$kBaseUrl$kMove/$idOrName';
  }

  /// Get ability endpoint with validation
  /// Throws [ArgumentError] if idOrName is empty
  static String getAbilityEndpoint(String idOrName) {
    _validateInput(idOrName, 'Ability ID or name');
    return '$kBaseUrl$kAbility/$idOrName';
  }

  /// Get type endpoint with validation
  /// Throws [ArgumentError] if type is empty
  static String getTypeEndpoint(String type) {
    _validateInput(type, 'Type');
    return '$kBaseUrl$kType/$type';
  }

  /// Get item endpoint with validation
  /// Throws [ArgumentError] if idOrName is empty
  static String getItemEndpoint(String idOrName) {
    _validateInput(idOrName, 'Item ID or name');
    return '$kBaseUrl$kItem/$idOrName';
  }

  /// Get location endpoint with validation
  /// Throws [ArgumentError] if idOrName is empty
  static String getLocationEndpoint(String idOrName) {
    _validateInput(idOrName, 'Location ID or name');
    return '$kBaseUrl$kLocation/$idOrName';
  }

  /// Get nature endpoint with validation
  /// Throws [ArgumentError] if nature is empty
  static String getNatureEndpoint(String nature) {
    _validateInput(nature, 'Nature');
    return '$kBaseUrl$kNature/$nature';
  }

  /// Get egg group endpoint with validation
  /// Throws [ArgumentError] if group is empty
  static String getEggGroupEndpoint(String group) {
    _validateInput(group, 'Egg group');
    return '$kBaseUrl$kEggGroup/$group';
  }

  /// Get official artwork URL with validation
  /// Throws [ArgumentError] if pokemonId is not positive
  static String getOfficialArtwork(int pokemonId) {
    _validateId(pokemonId, 'Pokemon ID');
    return '$kSpritesBaseUrl/sprites/pokemon/other/official-artwork/$pokemonId.png';
  }

  /// Get shiny official artwork URL with validation
  /// Throws [ArgumentError] if pokemonId is not positive
  static String getShinyOfficialArtwork(int pokemonId) {
    _validateId(pokemonId, 'Pokemon ID');
    return '$kSpritesBaseUrl/sprites/pokemon/other/official-artwork/shiny/$pokemonId.png';
  }

  /// Get Pokemon cry sound URL with validation
  /// Throws [ArgumentError] if pokemonId is not positive
  static String getPokemonCry(int pokemonId) {
    _validateId(pokemonId, 'Pokemon ID');
    return '$kSoundBaseUrl/$pokemonId.mp3';
  }

  /// Get user document path with validation
  /// Throws [ArgumentError] if uid is empty
  static String getUserDocument(String uid) {
    _validateInput(uid, 'User ID');
    return '$kUsersCollection/$uid';
  }

  /// Get user favorites path with validation
  /// Throws [ArgumentError] if uid is empty
  static String getUserFavorites(String uid) {
    _validateInput(uid, 'User ID');
    return '$kUsersCollection/$uid/$kFavoritesCollection';
  }

  /// Get user settings path with validation
  /// Throws [ArgumentError] if uid is empty
  static String getUserSettings(String uid) {
    _validateInput(uid, 'User ID');
    return '$kUsersCollection/$uid/$kSettingsCollection';
  }

  /// Get cache key for Pokemon list with validation
  /// Throws [ArgumentError] if offset is negative or limit is invalid
  static String getPokemonListCacheKey(int offset, int limit) {
    if (offset < 0) throw ArgumentError('Offset must be non-negative');
    if (limit <= 0 || limit > kItemsPerPage) {
      throw ArgumentError(
          'Invalid limit value: must be between 1 and $kItemsPerPage');
    }
    return '${kPokemonListKey}_${offset}_$limit';
  }

  /// Get cache key for Pokemon detail with validation
  /// Throws [ArgumentError] if idOrName is empty
  static String getPokemonDetailCacheKey(String idOrName) {
    _validateInput(idOrName, 'Pokemon ID or name');
    return 'pokemon_detail_$idOrName';
  }

  /// Get cache key for evolution chain with validation
  /// Throws [ArgumentError] if id is not positive
  static String getEvolutionChainCacheKey(int id) {
    _validateId(id, 'Evolution chain ID');
    return 'evolution_chain_$id';
  }

  // Error & Fallback Paths - Properly typed
  static const String kErrorImage = 'assets/images/error_pokemon.png';
  static const String kPlaceholderImage =
      'assets/images/placeholder_pokemon.png';
  static const String kLoadingImage = 'assets/images/loading_pokemon.gif';

  /// Validate URL string
  /// Returns true if URL is valid, false otherwise
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

  /// Validate input string
  /// Throws [ArgumentError] if input is empty
  static void _validateInput(String input, String fieldName) {
    if (input.isEmpty) {
      throw ArgumentError('$fieldName cannot be empty');
    }
  }

  /// Validate ID
  /// Throws [ArgumentError] if id is not positive
  static void _validateId(int id, String fieldName) {
    if (id <= 0) {
      throw ArgumentError('$fieldName must be positive');
    }
  }

  // Private constructor to prevent instantiation
  const ApiPaths._();
}
