// lib/core/constants/api_paths.dart

/// API path constants with validation, versioning and proper organization
class ApiPaths {
  // Base URLs with version control
  static const String apiVersion = 'v2';
  static const String pokeApiBase = 'https://pokeapi.co/api/$apiVersion';
  static const String pokeApiSprites =
      'https://raw.githubusercontent.com/PokeAPI/sprites/master';

  // Core API endpoints with validation
  static const String pokemonList = '/pokemon';
  static const String pokemonDetail = '/pokemon/{id}';
  static const String pokemonSpecies = '/pokemon-species/{id}';
  static const String evolutionChain = '/evolution-chain/{id}';
  static const String pokemonMove = '/move/{id}';
  static const String pokemonType = '/type/{id}';
  static const String pokemonAbility = '/ability/{id}';

  // Media URLs with validation
  static String getOfficialArtwork(int pokemonId) {
    assert(pokemonId > 0, 'Pokemon ID must be positive');
    return '$pokeApiSprites/sprites/pokemon/other/official-artwork/$pokemonId.png';
  }

  static String getPokemonSprite(int pokemonId) {
    assert(pokemonId > 0, 'Pokemon ID must be positive');
    return '$pokeApiSprites/sprites/pokemon/$pokemonId.png';
  }

  static String getShinySprite(int pokemonId) {
    assert(pokemonId > 0, 'Pokemon ID must be positive');
    return '$pokeApiSprites/sprites/pokemon/shiny/$pokemonId.png';
  }

  // Firebase Collections with security rules
  static const String usersCollection = 'users';
  static const String favoritesCollection = 'favorites';
  static const String settingsCollection = 'settings';

  // Firebase Document Paths with validation
  static String userDocument(String uid) {
    assert(uid.isNotEmpty, 'UID cannot be empty');
    return 'users/$uid';
  }

  static String userFavorites(String uid) {
    assert(uid.isNotEmpty, 'UID cannot be empty');
    return 'users/$uid/favorites';
  }

  static String userSettings(String uid) {
    assert(uid.isNotEmpty, 'UID cannot be empty');
    return 'users/$uid/settings';
  }

  // API Request Helper Methods with validation
  static String pokemonDetailPath(String idOrName) {
    assert(idOrName.isNotEmpty, 'ID or name cannot be empty');
    return pokemonDetail.replaceAll('{id}', idOrName);
  }

  static String pokemonSpeciesPath(String idOrName) {
    assert(idOrName.isNotEmpty, 'ID or name cannot be empty');
    return pokemonSpecies.replaceAll('{id}', idOrName);
  }

  static String evolutionChainPath(String id) {
    assert(id.isNotEmpty, 'ID cannot be empty');
    return evolutionChain.replaceAll('{id}', id);
  }

  static String pokemonMovePath(String id) {
    assert(id.isNotEmpty, 'ID cannot be empty');
    return pokemonMove.replaceAll('{id}', id);
  }

  static String pokemonTypePath(String id) {
    assert(id.isNotEmpty, 'ID cannot be empty');
    return pokemonType.replaceAll('{id}', id);
  }

  static String pokemonAbilityPath(String id) {
    assert(id.isNotEmpty, 'ID cannot be empty');
    return pokemonAbility.replaceAll('{id}', id);
  }

  // Pagination Parameters with constraints
  static const int defaultLimit = 20;
  static const int maxLimit = 100;

  // Cache Keys with validation
  static String pokemonListCacheKey(int offset, int limit) {
    assert(offset >= 0, 'Offset must be non-negative');
    assert(limit > 0 && limit <= maxLimit, 'Invalid limit value');
    return 'pokemon_list_${offset}_$limit';
  }

  static String pokemonDetailCacheKey(String idOrName) {
    assert(idOrName.isNotEmpty, 'ID or name cannot be empty');
    return 'pokemon_detail_$idOrName';
  }

  static String evolutionChainCacheKey(String id) {
    assert(id.isNotEmpty, 'ID cannot be empty');
    return 'evolution_chain_$id';
  }

  // Error Paths with fallbacks
  static const String defaultErrorImage = 'assets/images/error_pokemon.png';
  static const String placeholderImage =
      'assets/images/placeholder_pokemon.png';

  // Deep Link Paths with validation
  static const String deepLinkPrefix = 'pokedex://';

  static String pokemonDeepLink(int id) {
    assert(id > 0, 'Pokemon ID must be positive');
    return '${deepLinkPrefix}pokemon/$id';
  }

  static String favoriteDeepLink(String uid) {
    assert(uid.isNotEmpty, 'UID cannot be empty');
    return '${deepLinkPrefix}favorites/$uid';
  }

  // API Rate Limits
  static const int publicApiLimit = 100;
  static const int authenticatedApiLimit = 1000;

  // Connection Timeouts (milliseconds)
  static const int connectionTimeout = 10000;
  static const int receiveTimeout = 15000;
  static const int sendTimeout = 10000;

  // Cache Duration (hours)
  static const int cacheDuration = 24;

  // Offline Data Keys
  static const String offlinePokemonList = 'offline_pokemon_list';
  static const String offlineFavorites = 'offline_favorites';
  static const String offlineUserData = 'offline_user_data';

  // Private constructor to prevent instantiation
  const ApiPaths._();
}
