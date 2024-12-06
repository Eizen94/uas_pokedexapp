// lib/core/constants/api_paths.dart

class ApiPaths {
  // Base URLs
  static const String pokeApiBase = 'https://pokeapi.co/api/v2';
  static const String pokeApiSprites =
      'https://raw.githubusercontent.com/PokeAPI/sprites/master';

  // PokeAPI Endpoints
  static const String pokemonList = '/pokemon';
  static const String pokemonDetail = '/pokemon/{id}';
  static const String pokemonSpecies = '/pokemon-species/{id}';
  static const String evolutionChain = '/evolution-chain/{id}';
  static const String pokemonMove = '/move/{id}';
  static const String pokemonType = '/type/{id}';
  static const String pokemonAbility = '/ability/{id}';

  // Image URLs
  static String getOfficialArtwork(int pokemonId) =>
      '$pokeApiSprites/sprites/pokemon/other/official-artwork/$pokemonId.png';

  static String getPokemonSprite(int pokemonId) =>
      '$pokeApiSprites/sprites/pokemon/$pokemonId.png';

  static String getShinySprite(int pokemonId) =>
      '$pokeApiSprites/sprites/pokemon/shiny/$pokemonId.png';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String favoritesCollection = 'favorites';
  static const String settingsCollection = 'settings';

  // Firebase Document Paths
  static String userDocument(String uid) => 'users/$uid';
  static String userFavorites(String uid) => 'users/$uid/favorites';
  static String userSettings(String uid) => 'users/$uid/settings';

  // API Request Helper Methods
  static String pokemonDetailPath(String idOrName) =>
      pokemonDetail.replaceAll('{id}', idOrName);

  static String pokemonSpeciesPath(String idOrName) =>
      pokemonSpecies.replaceAll('{id}', idOrName);

  static String evolutionChainPath(String id) =>
      evolutionChain.replaceAll('{id}', id);

  static String pokemonMovePath(String id) =>
      pokemonMove.replaceAll('{id}', id);

  static String pokemonTypePath(String id) =>
      pokemonType.replaceAll('{id}', id);

  static String pokemonAbilityPath(String id) =>
      pokemonAbility.replaceAll('{id}', id);

  // Pagination Parameters
  static const int defaultLimit = 20;
  static const int maxLimit = 100;

  // Cache Keys
  static String pokemonListCacheKey(int offset, int limit) =>
      'pokemon_list_${offset}_$limit';

  static String pokemonDetailCacheKey(String idOrName) =>
      'pokemon_detail_$idOrName';

  static String evolutionChainCacheKey(String id) => 'evolution_chain_$id';

  // API Version
  static const String apiVersion = 'v2';

  // Error Paths
  static const String defaultErrorImage = 'assets/images/error_pokemon.png';
  static const String placeholderImage =
      'assets/images/placeholder_pokemon.png';

  // Deep Link Paths
  static const String deepLinkPrefix = 'pokedex://';
  static String pokemonDeepLink(int id) => '${deepLinkPrefix}pokemon/$id';
  static String favoriteDeepLink(String uid) =>
      '${deepLinkPrefix}favorites/$uid';

  // API Rate Limits (requests per minute)
  static const int publicApiLimit = 100;
  static const int authenticatedApiLimit = 1000;

  // Timeout Durations (in milliseconds)
  static const int connectionTimeout = 10000;
  static const int receiveTimeout = 15000;
  static const int sendTimeout = 10000;

  // Cache Duration (in hours)
  static const int cacheDuration = 24;

  // Offline Data Keys
  static const String offlinePokemonList = 'offline_pokemon_list';
  static const String offlineFavorites = 'offline_favorites';
  static const String offlineUserData = 'offline_user_data';
}
