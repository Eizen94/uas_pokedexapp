// lib/features/pokemon/widgets/pokemon_type_effectiveness.dart

import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../models/pokemon_detail_model.dart';

class PokemonTypeEffectiveness extends StatelessWidget {
  final List<String> types;

  const PokemonTypeEffectiveness({
    super.key,
    required this.types,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, double> effectiveness = _calculateEffectiveness();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type Effectiveness',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (effectiveness.isNotEmpty) ...[
              if (_getTypesByEffectiveness(effectiveness, 0).isNotEmpty)
                _buildEffectivenessSection(
                  'Immune to',
                  _getTypesByEffectiveness(effectiveness, 0),
                  Colors.grey,
                ),
              if (_getTypesByEffectiveness(effectiveness, 0.25).isNotEmpty)
                _buildEffectivenessSection(
                  'Very Resistant to',
                  _getTypesByEffectiveness(effectiveness, 0.25),
                  Colors.blue,
                ),
              if (_getTypesByEffectiveness(effectiveness, 0.5).isNotEmpty)
                _buildEffectivenessSection(
                  'Resistant to',
                  _getTypesByEffectiveness(effectiveness, 0.5),
                  Colors.green,
                ),
              if (_getTypesByEffectiveness(effectiveness, 2).isNotEmpty)
                _buildEffectivenessSection(
                  'Weak to',
                  _getTypesByEffectiveness(effectiveness, 2),
                  Colors.orange,
                ),
              if (_getTypesByEffectiveness(effectiveness, 4).isNotEmpty)
                _buildEffectivenessSection(
                  'Very Weak to',
                  _getTypesByEffectiveness(effectiveness, 4),
                  Colors.red,
                ),
            ] else
              const Center(
                child: Text('No type effectiveness data available'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectivenessSection(
    String title,
    List<String> types,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map((type) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.typeColors[type.toLowerCase()] ?? Colors.grey,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (AppColors.typeColors[type.toLowerCase()] ??
                            Colors.grey)
                        .withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                type.toUpperCase(),
                style: AppTextStyles.pokemonType.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Map<String, double> _calculateEffectiveness() {
    final Map<String, double> effectiveness = {};
    final Map<String, Map<String, double>> typeChart = _getTypeChart();

    // Initialize all types with 1x effectiveness
    for (final defendingType in typeChart.keys) {
      effectiveness[defendingType] = 1.0;
    }

    // Calculate effectiveness for each defending type
    for (final pokemonType in types) {
      final weaknesses = typeChart[pokemonType.toLowerCase()];
      if (weaknesses != null) {
        for (final entry in weaknesses.entries) {
          final defendingType = entry.key;
          final multiplier = entry.value;
          effectiveness[defendingType] =
              (effectiveness[defendingType] ?? 1.0) * multiplier;
        }
      }
    }

    return effectiveness;
  }

  List<String> _getTypesByEffectiveness(
    Map<String, double> effectiveness,
    double value,
  ) {
    return effectiveness.entries
        .where((entry) => entry.value == value)
        .map((entry) => entry.key)
        .toList()
      ..sort();
  }

  Map<String, Map<String, double>> _getTypeChart() {
    // Complete type chart with all effectiveness values
    return {
      'normal': {
        'ghost': 0,
        'rock': 0.5,
        'steel': 0.5,
      },
      'fire': {
        'fire': 0.5,
        'water': 0.5,
        'grass': 2,
        'ice': 2,
        'bug': 2,
        'rock': 0.5,
        'dragon': 0.5,
        'steel': 2,
      },
      'water': {
        'fire': 2,
        'water': 0.5,
        'grass': 0.5,
        'ground': 2,
        'rock': 2,
        'dragon': 0.5,
      },
      'electric': {
        'water': 2,
        'electric': 0.5,
        'grass': 0.5,
        'ground': 0,
        'flying': 2,
        'dragon': 0.5,
      },
      'grass': {
        'fire': 0.5,
        'water': 2,
        'grass': 0.5,
        'poison': 0.5,
        'ground': 2,
        'flying': 0.5,
        'bug': 0.5,
        'rock': 2,
        'dragon': 0.5,
        'steel': 0.5,
      },
      'ice': {
        'fire': 0.5,
        'water': 0.5,
        'grass': 2,
        'ice': 0.5,
        'ground': 2,
        'flying': 2,
        'dragon': 2,
        'steel': 0.5,
      },
      'fighting': {
        'normal': 2,
        'ice': 2,
        'poison': 0.5,
        'flying': 0.5,
        'psychic': 0.5,
        'bug': 0.5,
        'rock': 2,
        'ghost': 0,
        'dark': 2,
        'steel': 2,
        'fairy': 0.5,
      },
      'poison': {
        'grass': 2,
        'poison': 0.5,
        'ground': 0.5,
        'rock': 0.5,
        'ghost': 0.5,
        'steel': 0,
        'fairy': 2,
      },
      'ground': {
        'fire': 2,
        'electric': 2,
        'grass': 0.5,
        'poison': 2,
        'flying': 0,
        'bug': 0.5,
        'rock': 2,
        'steel': 2,
      },
      'flying': {
        'electric': 0.5,
        'grass': 2,
        'fighting': 2,
        'bug': 2,
        'rock': 0.5,
        'steel': 0.5,
      },
      'psychic': {
        'fighting': 2,
        'poison': 2,
        'psychic': 0.5,
        'dark': 0,
        'steel': 0.5,
      },
      'bug': {
        'fire': 0.5,
        'grass': 2,
        'fighting': 0.5,
        'poison': 0.5,
        'flying': 0.5,
        'psychic': 2,
        'ghost': 0.5,
        'dark': 2,
        'steel': 0.5,
        'fairy': 0.5,
      },
      'rock': {
        'fire': 2,
        'ice': 2,
        'fighting': 0.5,
        'ground': 0.5,
        'flying': 2,
        'bug': 2,
        'steel': 0.5,
      },
      'ghost': {
        'normal': 0,
        'psychic': 2,
        'ghost': 2,
        'dark': 0.5,
      },
      'dragon': {
        'dragon': 2,
        'steel': 0.5,
        'fairy': 0,
      },
      'dark': {
        'fighting': 0.5,
        'psychic': 2,
        'ghost': 2,
        'dark': 0.5,
        'fairy': 0.5,
      },
      'steel': {
        'fire': 0.5,
        'water': 0.5,
        'electric': 0.5,
        'ice': 2,
        'rock': 2,
        'steel': 0.5,
        'fairy': 2,
      },
      'fairy': {
        'fire': 0.5,
        'fighting': 2,
        'poison': 0.5,
        'dragon': 2,
        'dark': 2,
        'steel': 0.5,
      },
    };
  }
}

/// Example usage:
///```dart
/// PokemonTypeEffectiveness(
///   types: pokemon.types,
/// )
///```