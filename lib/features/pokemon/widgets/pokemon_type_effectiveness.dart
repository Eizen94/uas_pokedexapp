// lib/widgets/type_effectiveness.dart

/// Type effectiveness grid to display Pokemon type matchups.
/// Shows damage multipliers for attacking and defending scenarios.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import 'pokemon_type_badge.dart';

/// Type effectiveness grid widget
class TypeEffectivenessGrid extends StatelessWidget {
  /// Pokemon types to analyze
  final List<String> types;

  /// Whether to show defensive matchups
  final bool showDefensive;

  /// Constructor
  const TypeEffectivenessGrid({
    required this.types,
    this.showDefensive = true,
    super.key,
  });

  /// Calculate type effectiveness
  Map<String, double> _calculateEffectiveness() {
    final Map<String, double> effectiveness = {};

    // Complete type effectiveness matrix
    const typeChart = {
      'normal': {
        'fighting': 2.0,
        'ghost': 0.0,
      },
      'fire': {
        'water': 2.0,
        'ground': 2.0,
        'rock': 2.0,
        'bug': 0.5,
        'steel': 0.5,
        'fire': 0.5,
        'grass': 0.5,
        'ice': 0.5,
        'fairy': 0.5,
      },
      'water': {
        'electric': 2.0,
        'grass': 2.0,
        'fire': 0.5,
        'water': 0.5,
        'ice': 0.5,
        'steel': 0.5,
      },
      'electric': {
        'ground': 2.0,
        'flying': 0.5,
        'electric': 0.5,
        'steel': 0.5,
      },
      'grass': {
        'fire': 2.0,
        'ice': 2.0,
        'poison': 2.0,
        'flying': 2.0,
        'bug': 2.0,
        'water': 0.5,
        'ground': 0.5,
        'grass': 0.5,
        'electric': 0.5,
      },
      'ice': {
        'fire': 2.0,
        'fighting': 2.0,
        'rock': 2.0,
        'steel': 2.0,
        'ice': 0.5,
      },
      'fighting': {
        'flying': 2.0,
        'psychic': 2.0,
        'fairy': 2.0,
        'bug': 0.5,
        'rock': 0.5,
        'dark': 0.5,
      },
      'poison': {
        'ground': 2.0,
        'psychic': 2.0,
        'fighting': 0.5,
        'poison': 0.5,
        'bug': 0.5,
        'grass': 0.5,
        'fairy': 0.5,
      },
      'ground': {
        'water': 2.0,
        'grass': 2.0,
        'ice': 2.0,
        'poison': 0.5,
        'rock': 0.5,
        'electric': 0.0,
      },
      'flying': {
        'electric': 2.0,
        'ice': 2.0,
        'rock': 2.0,
        'fighting': 0.5,
        'ground': 0.0,
        'bug': 0.5,
        'grass': 0.5,
      },
      'psychic': {
        'bug': 2.0,
        'ghost': 2.0,
        'dark': 2.0,
        'fighting': 0.5,
        'psychic': 0.5,
      },
      'bug': {
        'fire': 2.0,
        'flying': 2.0,
        'rock': 2.0,
        'fighting': 0.5,
        'ground': 0.5,
        'grass': 0.5,
      },
      'rock': {
        'water': 2.0,
        'grass': 2.0,
        'fighting': 2.0,
        'ground': 2.0,
        'steel': 2.0,
        'normal': 0.5,
        'fire': 0.5,
        'poison': 0.5,
        'flying': 0.5,
      },
      'ghost': {
        'ghost': 2.0,
        'dark': 2.0,
        'poison': 0.5,
        'bug': 0.5,
        'normal': 0.0,
        'fighting': 0.0,
      },
      'dragon': {
        'ice': 2.0,
        'dragon': 2.0,
        'fairy': 2.0,
        'fire': 0.5,
        'water': 0.5,
        'grass': 0.5,
        'electric': 0.5,
      },
      'dark': {
        'fighting': 2.0,
        'bug': 2.0,
        'fairy': 2.0,
        'ghost': 0.5,
        'dark': 0.5,
        'psychic': 0.0,
      },
      'steel': {
        'fire': 2.0,
        'fighting': 2.0,
        'ground': 2.0,
        'normal': 0.5,
        'grass': 0.5,
        'ice': 0.5,
        'flying': 0.5,
        'psychic': 0.5,
        'bug': 0.5,
        'rock': 0.5,
        'dragon': 0.5,
        'steel': 0.5,
        'fairy': 0.5,
        'poison': 0.0,
      },
      'fairy': {
        'poison': 2.0,
        'steel': 2.0,
        'fighting': 0.5,
        'bug': 0.5,
        'dark': 0.5,
        'dragon': 0.0,
      },
    };

    for (final type in types) {
      final matchups = typeChart[type.toLowerCase()] ?? {};
      matchups.forEach((defType, multiplier) {
        if (showDefensive) {
          effectiveness[defType] = (effectiveness[defType] ?? 1.0) * multiplier;
        } else {
          effectiveness[defType] = multiplier;
        }
      });
    }

    return effectiveness;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveness = _calculateEffectiveness();

    // Group by effectiveness
    final superEffective = <String>[];
    final notVeryEffective = <String>[];
    final noEffect = <String>[];

    effectiveness.forEach((type, multiplier) {
      if (multiplier > 1) {
        superEffective.add(type);
      } else if (multiplier < 1 && multiplier > 0) {
        notVeryEffective.add(type);
      } else if (multiplier == 0) {
        noEffect.add(type);
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Text(
          showDefensive ? 'Defensive Type' : 'Offensive Type',
          style: AppTextStyles.heading3,
        ),
        const SizedBox(height: 16),

        // Effectiveness groups
        if (superEffective.isNotEmpty)
          _EffectivenessSection(
            title: '2× Damage',
            types: superEffective,
            color: AppColors.error,
          ),

        if (notVeryEffective.isNotEmpty)
          _EffectivenessSection(
            title: '½× Damage',
            types: notVeryEffective,
            color: AppColors.success,
          ),

        if (noEffect.isNotEmpty)
          _EffectivenessSection(
            title: 'No Effect',
            types: noEffect,
            color: AppColors.secondaryText,
          ),
      ],
    );
  }
}

/// Effectiveness section widget
class _EffectivenessSection extends StatelessWidget {
  /// Section title
  final String title;

  /// Pokemon types
  final List<String> types;

  /// Section color
  final Color color;

  const _EffectivenessSection({
    required this.title,
    required this.types,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Type badges grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types
              .map((type) => PokemonTypeBadge(
                    type: type,
                    size: BadgeSize.small,
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
