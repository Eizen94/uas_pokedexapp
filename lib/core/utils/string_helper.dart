// lib/core/utils/string_helper.dart

import 'package:flutter/foundation.dart';

class StringHelper {
  // Private constructor to prevent instantiation
  StringHelper._();

  // Pokemon name formatting
  static String formatPokemonName(String name) {
    try {
      if (name.isEmpty) return '';

      // Handle special cases
      if (name.toLowerCase().startsWith('nidoran-')) {
        return 'Nidoran${name.substring(name.length - 1)}';
      }

      // Split by hyphens and spaces
      final parts = name.split(RegExp(r'[-\s]'));

      return parts.map((part) {
        if (part.isEmpty) return '';
        // Handle special abbreviations
        if (_isSpecialAbbreviation(part)) return part.toUpperCase();
        // Capitalize first letter
        return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
      }).join(' ');
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting Pokemon name: $e');
      }
      return name;
    }
  }

  // Format Pokemon ID to 3-digit string
  static String formatPokemonId(int id) {
    try {
      return '#${id.toString().padLeft(3, '0')}';
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting Pokemon ID: $e');
      }
      return '#$id';
    }
  }

  // Format height to meters
  static String formatHeight(int decimeters) {
    try {
      final meters = decimeters / 10;
      return '${meters.toStringAsFixed(1)}m';
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting height: $e');
      }
      return '${decimeters}dm';
    }
  }

  // Format weight to kilograms
  static String formatWeight(int hectograms) {
    try {
      final kilograms = hectograms / 10;
      return '${kilograms.toStringAsFixed(1)}kg';
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting weight: $e');
      }
      return '${hectograms}hg';
    }
  }

  // Format stat name
  static String formatStatName(String stat) {
    try {
      // Map API stat names to display names
      final statMap = {
        'hp': 'HP',
        'attack': 'Attack',
        'defense': 'Defense',
        'special-attack': 'Sp. Atk',
        'special-defense': 'Sp. Def',
        'speed': 'Speed',
      };

      return statMap[stat.toLowerCase()] ?? _capitalizeWords(stat);
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting stat name: $e');
      }
      return stat;
    }
  }

  // Format ability name
  static String formatAbilityName(String ability) {
    try {
      return _capitalizeWords(ability.replaceAll('-', ' '));
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting ability name: $e');
      }
      return ability;
    }
  }

  // Format move name
  static String formatMoveName(String move) {
    try {
      return _capitalizeWords(move.replaceAll('-', ' '));
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting move name: $e');
      }
      return move;
    }
  }

  // Format type name
  static String formatTypeName(String type) {
    try {
      return type.toUpperCase();
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting type name: $e');
      }
      return type;
    }
  }

  // Format percentage
  static String formatPercentage(double value, {int decimals = 1}) {
    try {
      return '${value.toStringAsFixed(decimals)}%';
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting percentage: $e');
      }
      return '$value%';
    }
  }

  // Format large numbers with commas
  static String formatNumber(int number) {
    try {
      return number.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting number: $e');
      }
      return number.toString();
    }
  }

  // Helper method to capitalize words
  static String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // Check for special abbreviations that should be uppercase
  static bool _isSpecialAbbreviation(String text) {
    final specialCases = ['hp', 'pp', 'iv', 'ev'];
    return specialCases.contains(text.toLowerCase());
  }

  // Format genus text (e.g., "Seed Pokémon")
  static String formatGenus(String genus) {
    try {
      if (!genus.toLowerCase().contains('pokémon')) {
        return '$genus Pokémon';
      }
      return genus;
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting genus: $e');
      }
      return genus;
    }
  }

  // Format description text (clean up new lines and spaces)
  static String formatDescription(String description) {
    try {
      return description
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'\n+'), ' ')
          .trim();
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting description: $e');
      }
      return description;
    }
  }

  // Format evolution trigger text
  static String formatEvolutionTrigger(String trigger) {
    try {
      return trigger
          .replaceAll('-', ' ')
          .split(' ')
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting evolution trigger: $e');
      }
      return trigger;
    }
  }

  // Slugify text for URLs or IDs
  static String slugify(String text) {
    try {
      return text
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
    } catch (e) {
      if (kDebugMode) {
        print('Error slugifying text: $e');
      }
      return text.toLowerCase();
    }
  }
}
