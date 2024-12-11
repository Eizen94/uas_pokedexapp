// lib/core/constants/api_paths.dart

import 'dart:core';
import 'package:flutter/foundation.dart';

/// Complete API path management with validation, versioning and organization
class ApiPaths {
  // API Configuration
  static const String kApiVersion = 'v2';
  static const String kBaseUrl = 'https://pokeapi.co/api/$kApiVersion';
  static const String kSpritesBaseUrl =
      'https://raw.githubusercontent.com/PokeAPI/sprites/master';
  static const String kSoundBaseUrl =
      'https://play.pokemonshowdown.com/audio/cries';

  // Core Endpoints
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

  // Firebase Collections
  static const String kUsersCollection = 'users';
  static const String kFavoritesCollection = 'favorites';
  static const String kSettingsCollection = 'settings';
  static const String kCacheCollection = 'cache';

  // Cache Keys
  static const String kPokemonListKey = 'pokemon_list';
  static const String kTypeChartKey = 'type_chart';
  static const String kAbilityListKey = 'ability_list';
  static const String kMoveListKey = 'move_list';
  static const String kItemListKey = 'item_list';
  static const String kLocationListKey = 'location_list';
  static const String kNatureListKey = 'nature_list';

  // API Limits & Timeouts
  static const Duration kRequestTimeout = Duration(seconds: 30);
  static const Duration kCacheExpiration = Duration(hours: 24);
  static const int kMaxRequestRetries = 3;
  static const int kMaxConcurrentRequests = 5;
  static const int kItemsPerPage = 20;
  static const int kMaxCacheSize = 5 * 1024 * 1024; // 5MB

  /// Get Pokemon detail endpoint
  static String getPokemonEndpoint(String idOrName) {
    assert(idOrName.isNotEmpty, 'Pokemon ID or name cannot be empty');
    return '$kBaseUrl$kPokemon/$idOrName';
  }

  /// Get Pokemon species endpoint
  static String getPokemonSpeciesEndpoint(String idOrName) {
    assert(idOrName.isNotEmpty, 'Pokemon ID or name cannot be empty');
    return '$kBaseUrl$kPokemonSpecies/$idOrName';
  }

  /// Get evolution chain endpoint
  static String getEvolutionChainEndpoint(int id) {
    assert(id > 0, 'Evolution chain ID must be positive');
    return '$kBaseUrl$kEvolutionChain/$id';
  }

  /// Get move endpoint
  static String getMoveEndpoint(String idOrName) {
    assert(idOrName.isNotEmpty, 'Move ID or name cannot be empty');
    return '$kBaseUrl$kMove/$idOrName';
  }

  /// Get ability endpoint
  static String getAbilityEndpoint(String idOrName) {
    assert(idOrName.isNotEmpty, 'Ability ID or name cannot be empty');
    return '$kBaseUrl$kAbility/$idOrName';
  }

  /// Get type endpoint
  static String getTypeEndpoint(String type) {
    assert(type.isNotEmpty, 'Type cannot be empty');
    return '$kBaseUrl$kType/$type';
  }

  /// Get item endpoint
  static String getItemEndpoint(String idOrName) {
    assert(idOrName.isNotEmpty, 'Item ID or name cannot be empty');
    return '$kBaseUrl$kItem/$idOrName';
  }

  /// Get location endpoint
  static String getLocationEndpoint(String idOrName) {
    assert(idOrName.isNotEmpty, 'Location ID or name cannot be empty');
    return '$kBaseUrl$kLocation/$idOrName';
  }

  /// Get nature endpoint
  static String getNatureEndpoint(String nature) {
    assert(nature.isNotEmpty, 'Nature cannot be empty');
    return '$kBaseUrl$kNature/$nature';
  }

  /// Get egg group endpoint
  static String getEggGroupEndpoint(String group) {
    assert(group.isNotEmpty, 'Egg group cannot be empty');
    return '$kBaseUrl$kEggGroup/$group';
  }

  /// Get official artwork URL
  static String getOfficialArtwork(int pokemonId) {
    assert(pokemonId > 0, 'Pokemon ID must be positive');
    return '$kSpritesBaseUrl/sprites/pokemon/other/official-artwork/$pokemonId.png';
  }

  /// Get shiny official artwork URL
  static String getShinyOfficialArtwork(int pokemonId) {
    assert(pokemonId > 0, 'Pokemon ID must be positive');
    return '$kSpritesBaseUrl/sprites/pokemon/other/official-artwork/shiny/$pokemonId.png';
  }

  /// Get Pokemon cry sound URL
  static String getPokemonCry(int pokemonId) {
    assert(pokemonId > 0, 'Pokemon ID must be positive');
    return '$kSoundBaseUrl/$pokemonId.mp3';
  }

  /// Get user document path
  static String getUserDocument(String uid) {
    assert(uid.isNotEmpty, 'User ID cannot be empty');
    return '$kUsersCollection/$uid';
  }

  /// Get user favorites path
  static String getUserFavorites(String uid) {
    assert(uid.isNotEmpty, 'User ID cannot be empty');
    return '$kUsersCollection/$uid/$kFavoritesCollection';
  }

  /// Get user settings path
  static String getUserSettings(String uid) {
    assert(uid.isNotEmpty, 'User ID cannot be empty');
    return '$kUsersCollection/$uid/$kSettingsCollection';
  }

  /// Get cache key for Pokemon list
  static String getPokemonListCacheKey(int offset, int limit) {
    assert(offset >= 0, 'Offset must be non-negative');
    assert(limit > 0 && limit <= kItemsPerPage, 'Invalid limit value');
    return '${kPokemonListKey}_${offset}_$limit';
  }

  /// Get cache key for Pokemon detail
  static String getPokemonDetailCacheKey(String idOrName) {
    assert(idOrName.isNotEmpty, 'Pokemon ID or name cannot be empty');
    return 'pokemon_detail_$idOrName';
  }

  /// Get cache key for evolution chain
  static String getEvolutionChainCacheKey(int id) {
    assert(id > 0, 'Evolution chain ID must be positive');
    return 'evolution_chain_$id';
  }

  // Error & Fallback Paths
  static const String kErrorImage = 'assets/images/error_pokemon.png';
  static const String kPlaceholderImage =
      'assets/images/placeholder_pokemon.png';
  static const String kLoadingImage = 'assets/images/loading_pokemon.gif';

  // Private constructor to prevent instantiation
  const ApiPaths._();

  /// Validate URL string
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
}
