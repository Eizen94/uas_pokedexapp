// lib/core/utils/string_helper.dart

/// String helper utility for consistent string formatting and validation.
/// Provides unified string manipulation across the application.
library;

/// Helper class for string operations
class StringHelper {
  const StringHelper._();

  /// Format Pokemon ID to 3-digit format
  /// Example: 1 -> #001, 25 -> #025
  static String formatPokemonId(int id) {
    return '#${id.toString().padLeft(3, '0')}';
  }

  /// Format Pokemon name to title case
  /// Example: pikachu -> Pikachu
  static String formatPokemonName(String name) {
    if (name.isEmpty) return '';
    return name[0].toUpperCase() + name.substring(1).toLowerCase();
  }

  /// Format Pokemon stats
  /// Example: 100 -> 100.0
  static String formatStat(num value) {
    return value.toStringAsFixed(1);
  }

  /// Format Pokemon height (convert to meters)
  /// Example: 7 -> 0.7m
  static String formatHeight(num decimeters) {
    final meters = decimeters / 10;
    return '${meters.toStringAsFixed(1)}m';
  }

  /// Format Pokemon weight (convert to kilograms)
  /// Example: 60 -> 6.0kg
  static String formatWeight(num hectograms) {
    final kilograms = hectograms / 10;
    return '${kilograms.toStringAsFixed(1)}kg';
  }

  /// Format Pokemon types list
  /// Example: [fire, flying] -> Fire/Flying
  static String formatTypes(List<String> types) {
    return types.map((type) => formatPokemonName(type)).join('/');
  }

  /// Format move accuracy
  /// Example: 90 -> 90%
  static String formatAccuracy(int? accuracy) {
    return accuracy != null ? '$accuracy%' : '-';
  }

  /// Format move power
  /// Example: 90 -> 90
  static String formatPower(int? power) {
    return power?.toString() ?? '-';
  }

  /// Format Pokemon description by removing unnecessary newlines and spaces
  static String formatDescription(String description) {
    return description
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Format generation number
  /// Example: 1 -> Generation I
  static String formatGeneration(int generation) {
    const romans = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'];
    if (generation < 1 || generation > romans.length) return 'Unknown';
    return 'Generation ${romans[generation - 1]}';
  }

  /// Format percentage
  /// Example: 0.856 -> 85.6%
  static String formatPercentage(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  /// Format timestamp to readable date
  /// Example: 2024-01-01 -> January 1, 2024
  static String formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Validate Pokemon name (alphanumeric and hyphen only)
  static bool isValidPokemonName(String name) {
    return RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(name);
  }

  /// Get Pokemon color name from type
  static String getColorName(String type) {
    return type.toLowerCase();
  }

  /// Format search query for API
  static String formatSearchQuery(String query) {
    return query.trim().toLowerCase();
  }

  /// Remove diacritics from text
  static String removeDiacritics(String text) {
    return text
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll(RegExp(r'[ñ]'), 'n');
  }
}