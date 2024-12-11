// lib/core/utils/string_helper.dart

import 'package:flutter/foundation.dart';

/// String helper utilities with proper validation and error handling
class StringHelper {
  // Private constructor to prevent instantiation
  StringHelper._();

  /// Pokemon name formatting with proper validation
  static String formatPokemonName(String name) {
    try {
      if (name.isEmpty) return '';

      // Handle special cases
      if (name.toLowerCase().startsWith('nidoran-')) {
        return 'Nidoran${name.substring(name.length - 1)}';
      }

      // Split by hyphens or spaces
      final parts = name.split(RegExp(r'[-\s]'));

      return parts.map((part) {
        if (part.isEmpty) return '';
        // Handle special cases
        if (_isSpecialAbbreviation(part)) {
          return part.toUpperCase();
        }
        // Regular capitalization
        return _capitalize(part);
      }).join(' ');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error formatting Pokemon name: $e');
      }
      return name;
    }
  }

  /// Format Pokemon stats with proper type handling
  static String formatStatName(String stat) {
    try {
      // Map common stat abbreviations
      final statMap = {
        'hp': 'HP',
        'atk': 'Attack',
        'def': 'Defense',
        'spa': 'Sp. Atk',
        'spd': 'Sp. Def',
        'spe': 'Speed',
        'special-attack': 'Sp. Atk',
        'special-defense': 'Sp. Def',
      };

      final normalizedStat = stat.toLowerCase();
      if (statMap.containsKey(normalizedStat)) {
        return statMap[normalizedStat]!;
      }

      return _formatWords(stat);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error formatting stat name: $e');
      }
      return stat;
    }
  }

  /// Format numbers with proper padding
  static String formatNumber(int number, {int padLength = 3}) {
    try {
      return number.toString().padLeft(padLength, '0');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error formatting number: $e');
      }
      return number.toString();
    }
  }

  /// Format decimal numbers with precision
  static String formatDecimal(double number, {int decimals = 1}) {
    try {
      return number.toStringAsFixed(decimals);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error formatting decimal: $e');
      }
      return number.toString();
    }
  }

  /// Format height from decimeters to meters
  static String formatHeight(int decimeters) {
    try {
      final meters = decimeters / 10;
      return '${formatDecimal(meters)}m';
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error formatting height: $e');
      }
      return '${decimeters}dm';
    }
  }

  /// Format weight from hectograms to kilograms
  static String formatWeight(int hectograms) {
    try {
      final kilograms = hectograms / 10;
      return '${formatDecimal(kilograms)}kg';
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error formatting weight: $e');
      }
      return '${hectograms}hg';
    }
  }

  /// Format move names with proper capitalization
  static String formatMoveName(String move) {
    try {
      return _formatWords(move);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error formatting move name: $e');
      }
      return move;
    }
  }

  /// Format ability names with proper capitalization
  static String formatAbilityName(String ability) {
    try {
      return _formatWords(ability);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error formatting ability name: $e');
      }
      return ability;
    }
  }

  /// Format percentages with proper decimals
  static String formatPercentage(double value, {int decimals = 1}) {
    try {
      return '${formatDecimal(value, decimals: decimals)}%';
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error formatting percentage: $e');
      }
      return '$value%';
    }
  }

  /// Format large numbers with comma separators
  static String formatLargeNumber(int number) {
    try {
      return number.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error formatting large number: $e');
      }
      return number.toString();
    }
  }

  /// Format Pokemon types to uppercase
  static String formatType(String type) {
    try {
      return type.toUpperCase();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error formatting type: $e');
      }
      return type;
    }
  }

  /// Format description text
  static String formatDescription(String description) {
    try {
      return description
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'\n+'), ' ')
          .trim();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error formatting description: $e');
      }
      return description;
    }
  }

  /// Helper to capitalize first letter
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Helper to format words with proper spacing
  static String _formatWords(String text) {
    return text
        .split(RegExp(r'[-\s]'))
        .map((word) => _capitalize(word))
        .join(' ');
  }

  /// Check for special abbreviations
  static bool _isSpecialAbbreviation(String text) {
    final specialCases = ['hp', 'pp', 'iv', 'ev'];
    return specialCases.contains(text.toLowerCase());
  }

  /// Create URL-safe slugs
  static String slugify(String text) {
    try {
      return text
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error slugifying text: $e');
      }
      return text.toLowerCase();
    }
  }

  /// Format error messages properly
  static String formatErrorMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred';

    try {
      if (error is Exception) {
        return error.toString().replaceAll('Exception: ', '');
      }
      return error.toString();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error formatting error message: $e');
      }
      return 'An unknown error occurred';
    }
  }

  /// Convert to safe filename
  static String toSafeFileName(String text) {
    try {
      return text
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error converting to safe filename: $e');
      }
      return text.toLowerCase();
    }
  }

  /// Remove special characters
  static String removeSpecialCharacters(String text) {
    try {
      return text.replaceAll(RegExp(r'[^\w\s-]'), '');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removing special characters: $e');
      }
      return text;
    }
  }
}
