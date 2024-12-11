// lib/core/utils/string_helper.dart

// Dart imports
import 'dart:convert';
import 'dart:math' as math;

// Package imports
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Enhanced string helper utilities with proper validation and error handling.
/// Provides comprehensive string manipulation for Pokemon data formatting.
class StringHelper {
  // Pokemon specific formatters
  static final _pokemonIdFormat = NumberFormat('000');
  static final _statFormat = NumberFormat('000');
  static final _percentageFormat = NumberFormat('##0.0');

  // Regular expressions
  static final _numericRegex = RegExp(r'[^0-9]');
  static final _specialCharsRegex = RegExp(r'[^\w\s-]');
  static final _multipleSpacesRegex = RegExp(r'\s+');
  static final _validNameRegex = RegExp(r'^[a-zA-Z0-9\s\-]+$');

  // Constants
  static const String _placeholder = 'Unknown';
  static const int _maxNameLength = 50;
  static const int _minNameLength = 2;

  // Private constructor to prevent instantiation
  const StringHelper._();

  /// Format Pokemon name with proper validation
  static String formatPokemonName(String name) {
    try {
      if (name.isEmpty) return _placeholder;
      if (name.length > _maxNameLength) {
        name = name.substring(0, _maxNameLength);
      }

      // Handle special cases
      if (name.toLowerCase().startsWith('nidoran-')) {
        return 'Nidoran${name.substring(name.length - 1)}';
      }

      // Split by hyphens or spaces
      final parts = name.split(RegExp(r'[-\s]'));

      return parts
          .map((part) {
            if (part.isEmpty) return '';
            // Handle special cases
            if (_isSpecialAbbreviation(part)) {
              return part.toUpperCase();
            }
            // Regular capitalization
            return _capitalize(part);
          })
          .join(' ')
          .trim();
    } catch (e) {
      _logError('Error formatting Pokemon name', e);
      return name;
    }
  }

  /// Format Pokemon ID with padding
  static String formatPokemonId(int id) {
    try {
      return '#${_pokemonIdFormat.format(id)}';
    } catch (e) {
      _logError('Error formatting Pokemon ID', e);
      return '#$id';
    }
  }

  /// Format Pokemon stat with proper alignment
  static String formatStat(int value) {
    try {
      return _statFormat.format(value.clamp(0, 999));
    } catch (e) {
      _logError('Error formatting stat', e);
      return value.toString();
    }
  }

  /// Format height from decimeters to meters
  static String formatHeight(int decimeters) {
    try {
      final meters = decimeters / 10;
      return '${_formatDecimal(meters)}m';
    } catch (e) {
      _logError('Error formatting height', e);
      return '${decimeters}dm';
    }
  }

  /// Format weight from hectograms to kilograms
  static String formatWeight(int hectograms) {
    try {
      final kilograms = hectograms / 10;
      return '${_formatDecimal(kilograms)}kg';
    } catch (e) {
      _logError('Error formatting weight', e);
      return '${hectograms}hg';
    }
  }

  /// Format percentage value
  static String formatPercentage(double value) {
    try {
      return '${_percentageFormat.format(value.clamp(0.0, 100.0))}%';
    } catch (e) {
      _logError('Error formatting percentage', e);
      return '$value%';
    }
  }

  /// Format experience points
  static String formatExp(int exp) {
    try {
      return NumberFormat.decimalPattern().format(exp);
    } catch (e) {
      _logError('Error formatting exp', e);
      return exp.toString();
    }
  }

  /// Format Pokemon move name
  static String formatMoveName(String move) {
    try {
      return move.split('-').map(_capitalize).join(' ');
    } catch (e) {
      _logError('Error formatting move name', e);
      return move;
    }
  }

  /// Format Pokemon ability name
  static String formatAbilityName(String ability) {
    try {
      return ability.split('-').map(_capitalize).join(' ');
    } catch (e) {
      _logError('Error formatting ability name', e);
      return ability;
    }
  }

  /// Format Pokemon type name
  static String formatTypeName(String type) {
    try {
      return type.toUpperCase();
    } catch (e) {
      _logError('Error formatting type name', e);
      return type;
    }
  }

  /// Format description text
  static String formatDescription(String description) {
    try {
      return description
          .replaceAll(_multipleSpacesRegex, ' ')
          .replaceAll('\n', ' ')
          .trim();
    } catch (e) {
      _logError('Error formatting description', e);
      return description;
    }
  }

  /// Create URL-safe slug
  static String slugify(String text) {
    try {
      return text
          .toLowerCase()
          .replaceAll(_specialCharsRegex, '')
          .replaceAll(_multipleSpacesRegex, '-');
    } catch (e) {
      _logError('Error creating slug', e);
      return text.toLowerCase();
    }
  }

  /// Format error message
  static String formatErrorMessage(dynamic error) {
    if (error == null) return 'An unknown error occurred';

    try {
      if (error is Exception) {
        return error.toString().replaceAll('Exception: ', '');
      }
      return error.toString();
    } catch (e) {
      _logError('Error formatting error message', e);
      return 'An unknown error occurred';
    }
  }

  /// Create safe filename
  static String toSafeFileName(String text) {
    try {
      return text
          .toLowerCase()
          .replaceAll(_specialCharsRegex, '_')
          .replaceAll(_multipleSpacesRegex, '_');
    } catch (e) {
      _logError('Error creating safe filename', e);
      return text.toLowerCase();
    }
  }

  /// Validate Pokemon name
  static bool isValidPokemonName(String name) {
    if (name.length < _minNameLength || name.length > _maxNameLength) {
      return false;
    }
    return _validNameRegex.hasMatch(name);
  }

  /// Extract numbers from string
  static String extractNumbers(String text) {
    try {
      return text.replaceAll(_numericRegex, '');
    } catch (e) {
      _logError('Error extracting numbers', e);
      return '';
    }
  }

  /// Truncate text with ellipsis
  static String truncate(String text, int maxLength) {
    try {
      if (text.length <= maxLength) return text;
      return '${text.substring(0, maxLength)}...';
    } catch (e) {
      _logError('Error truncating text', e);
      return text;
    }
  }

  /// Format decimal number
  static String _formatDecimal(double value, {int decimals = 1}) {
    try {
      return value.toStringAsFixed(decimals);
    } catch (e) {
      _logError('Error formatting decimal', e);
      return value.toString();
    }
  }

  /// Capitalize first letter
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Check for special abbreviations
  static bool _isSpecialAbbreviation(String text) {
    final specialCases = {'hp', 'pp', 'iv', 'ev'};
    return specialCases.contains(text.toLowerCase());
  }

  /// Log error with proper context
  static void _logError(String message, Object error) {
    if (kDebugMode) {
      print('❌ StringHelper: $message: $error');
    }
  }

  /// Encode string to base64
  static String encodeBase64(String text) {
    try {
      return base64Encode(utf8.encode(text));
    } catch (e) {
      _logError('Error encoding base64', e);
      return text;
    }
  }

  /// Decode base64 string
  static String decodeBase64(String encoded) {
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (e) {
      _logError('Error decoding base64', e);
      return encoded;
    }
  }
}
