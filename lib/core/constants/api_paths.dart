// lib/core/constants/api_paths.dart

/// API path constants for the Pokedex application.
/// Contains all endpoints and URL builders for API calls.
library core.constants.api_paths;

/// Base URLs for different API services
class ApiBaseUrls {
  const ApiBaseUrls._();

  /// PokeAPI base URL
  static const String pokeApi = 'https://pokeapi.co/api/v2';

  /// Pokemon images base URL
  static const String imageBaseUrl =
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

  /// Official artwork base URL
  static const String officialArtwork = '$imageBaseUrl/other/official-artwork';
}

/// API endpoints for Pokemon data
class ApiPaths {
  const ApiPaths._();

  /// Get Pokemon list with pagination
  /// @param limit Number of Pokemon to fetch
  /// @param offset Starting index
  static String pokemonList(int limit, int offset) =>
      '${ApiBaseUrls.pokeApi}/pokemon?limit=$limit&offset=$offset';

  /// Get Pokemon details by id
  /// @param id Pokemon ID
  static String pokemonDetails(int id) => '${ApiBaseUrls.pokeApi}/pokemon/$id';

  /// Get Pokemon species details
  /// @param id Pokemon ID
  static String pokemonSpecies(int id) =>
      '${ApiBaseUrls.pokeApi}/pokemon-species/$id';

  /// Get evolution chain details
  /// @param id Evolution chain ID
  static String evolutionChain(int id) =>
      '${ApiBaseUrls.pokeApi}/evolution-chain/$id';

  /// Get Pokemon type details
  /// @param id Type ID
  static String pokemonType(int id) => '${ApiBaseUrls.pokeApi}/type/$id';
}

/// Image URL builders for Pokemon assets
class PokemonImagePaths {
  const PokemonImagePaths._();

  /// Get official artwork URL
  /// @param id Pokemon ID
  static String officialArtwork(int id) =>
      '${ApiBaseUrls.officialArtwork}/$id.png';

  /// Get default sprite URL
  /// @param id Pokemon ID
  static String defaultSprite(int id) => '${ApiBaseUrls.imageBaseUrl}/$id.png';

  /// Get shiny sprite URL
  /// @param id Pokemon ID
  static String shinySprite(int id) =>
      '${ApiBaseUrls.imageBaseUrl}/shiny/$id.png';

  /// Get female sprite URL if available
  /// @param id Pokemon ID
  static String femaleSprite(int id) =>
      '${ApiBaseUrls.imageBaseUrl}/female/$id.png';

  /// Get shiny female sprite URL if available
  /// @param id Pokemon ID
  static String shinyFemaleSprite(int id) =>
      '${ApiBaseUrls.imageBaseUrl}/shiny/female/$id.png';
}

/// Cache keys for local storage
class CacheKeys {
  const CacheKeys._();

  /// Pokemon list cache key
  static String pokemonList(int limit, int offset) =>
      'pokemon_list_${limit}_$offset';

  /// Pokemon details cache key
  static String pokemonDetails(int id) => 'pokemon_details_$id';

  /// Pokemon species cache key
  static String pokemonSpecies(int id) => 'pokemon_species_$id';

  /// Evolution chain cache key
  static String evolutionChain(int id) => 'evolution_chain_$id';

  /// Pokemon type cache key
  static String pokemonType(int id) => 'pokemon_type_$id';
}
