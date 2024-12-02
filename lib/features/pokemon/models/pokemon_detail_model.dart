// lib/features/pokemon/models/pokemon_detail_model.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'pokemon_model.dart';

class PokemonDetailModel extends PokemonModel {
  final List<Ability> abilities;
  @override // Explicitly mark as override
  final Map<String, dynamic> stats; // Changed to match parent type
  final List<Stat> statsList; // New field for typed stats
  final List<String> moves;
  final String species;
  final Evolution? evolution;

  PokemonDetailModel({
    required super.id,
    required super.name,
    required super.imageUrl,
    required super.types,
    required super.height,
    required super.weight,
    required this.abilities,
    required Map<String, dynamic> stats,
    required this.statsList,
    required this.moves,
    required this.species,
    this.evolution,
  })  : stats = stats,
        super(stats: stats);

  factory PokemonDetailModel.fromJson(Map<String, dynamic> json) {
    try {
      // Parse abilities
      final abilitiesList = (json['abilities'] as List?)?.map((ability) {
            if (ability is Map<String, dynamic>) {
              return Ability.fromJson(ability);
            }
            throw FormatException('Invalid ability format');
          }).toList() ??
          [];

      // Parse stats
      final statsList = (json['stats'] as List?)?.map((stat) {
            if (stat is Map<String, dynamic>) {
              return Stat.fromJson(stat);
            }
            throw FormatException('Invalid stat format');
          }).toList() ??
          [];

      // Convert stats to Map format for parent class
      final statsMap = <String, dynamic>{};
      for (var stat in statsList) {
        statsMap[stat.name] = stat.baseStat;
      }

      // Parse moves
      final movesList = (json['moves'] as List?)?.map((move) {
            if (move is Map<String, dynamic> &&
                move['move'] is Map<String, dynamic> &&
                move['move']['name'] is String) {
              return move['move']['name'] as String;
            }
            return 'unknown';
          }).toList() ??
          [];

      return PokemonDetailModel(
        id: json['id'] as int,
        name: json['name'] as String,
        imageUrl:
            'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${json['id']}.png',
        types: (json['types'] as List)
            .map((type) => type['type']['name'] as String)
            .toList(),
        height: json['height'] as int,
        weight: json['weight'] as int,
        abilities: abilitiesList,
        stats: statsMap,
        statsList: statsList,
        moves: movesList,
        species: json['species']['name'] as String,
        evolution: json['evolution'] != null
            ? Evolution.fromJson(json['evolution'] as Map<String, dynamic>)
            : null,
      );
    } catch (e) {
      throw FormatException('Error parsing Pokemon detail data: $e');
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'abilities': abilities.map((ability) => ability.toJson()).toList(),
        'stats': stats,
        'statsList': statsList.map((stat) => stat.toJson()).toList(),
        'moves': moves,
        'species': species,
        'evolution': evolution?.toJson(),
      };

  // Helper Methods
  double getStatPercentage(String statName) {
    final stat = statsList.firstWhere(
      (stat) => stat.name == statName,
      orElse: () => Stat(name: statName, baseStat: 0, effort: 0),
    );
    return stat.baseStat / 255; // 255 is max possible stat
  }

  List<String> getAbilityNames() {
    return abilities.map((ability) => ability.name).toList();
  }

  List<String> getHiddenAbilities() {
    return abilities
        .where((ability) => ability.isHidden)
        .map((ability) => ability.name)
        .toList();
  }

  Map<String, int> getStatsMap() {
    return {
      for (var stat in statsList) stat.name: stat.baseStat,
    };
  }

  bool hasEvolution() => evolution != null && evolution!.stages.length > 1;

  List<int> getEvolutionIds() {
    if (evolution == null) return [];
    return evolution!.stages.map((stage) => stage.pokemonId).toList();
  }
}

class Ability {
  final String name;
  final bool isHidden;

  Ability({
    required this.name,
    required this.isHidden,
  });

  factory Ability.fromJson(Map<String, dynamic> json) {
    try {
      if (json['ability'] is! Map<String, dynamic>) {
        throw FormatException('Invalid ability data structure');
      }

      return Ability(
        name: json['ability']['name'] as String,
        isHidden: json['is_hidden'] as bool? ?? false,
      );
    } catch (e) {
      throw FormatException('Error parsing ability data: $e');
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'is_hidden': isHidden,
      };

  @override
  String toString() => json.encode(toJson());

  String getFormattedName() {
    return name
        .split('-')
        .map((word) => word.substring(0, 1).toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class Stat {
  final String name;
  final int baseStat;
  final int effort;

  Stat({
    required this.name,
    required this.baseStat,
    required this.effort,
  });

  factory Stat.fromJson(Map<String, dynamic> json) {
    try {
      if (json['stat'] is! Map<String, dynamic>) {
        throw FormatException('Invalid stat data structure');
      }

      return Stat(
        name: json['stat']['name'] as String,
        baseStat: json['base_stat'] as int? ?? 0,
        effort: json['effort'] as int? ?? 0,
      );
    } catch (e) {
      throw FormatException('Error parsing stat data: $e');
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'base_stat': baseStat,
        'effort': effort,
      };

  @override
  String toString() => json.encode(toJson());

  String getFormattedName() {
    return name
        .split('-')
        .map((word) => word.substring(0, 1).toUpperCase() + word.substring(1))
        .join(' ');
  }

  // Get color based on stat value
  Color getStatColor() {
    if (baseStat < 50) return Colors.red;
    if (baseStat < 100) return Colors.orange;
    return Colors.green;
  }
}

class Evolution {
  final int chainId;
  final List<EvolutionStage> stages;

  Evolution({
    required this.chainId,
    required this.stages,
  });

  factory Evolution.fromJson(Map<String, dynamic> json) {
    try {
      if (!json.containsKey('stages') || json['stages'] is! List) {
        throw FormatException('Invalid evolution chain structure');
      }

      return Evolution(
        chainId: json['chain_id'] as int? ?? 0,
        stages: (json['stages'] as List)
            .map((stage) =>
                EvolutionStage.fromJson(stage as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      throw FormatException('Error parsing evolution chain: $e');
    }
  }

  Map<String, dynamic> toJson() => {
        'chain_id': chainId,
        'stages': stages.map((stage) => stage.toJson()).toList(),
      };

  @override
  String toString() => json.encode(toJson());

  bool hasMultipleStages() => stages.length > 1;

  EvolutionStage? getNextEvolution(int currentId) {
    final currentIndex =
        stages.indexWhere((stage) => stage.pokemonId == currentId);
    if (currentIndex != -1 && currentIndex < stages.length - 1) {
      return stages[currentIndex + 1];
    }
    return null;
  }

  EvolutionStage? getPreviousEvolution(int currentId) {
    final currentIndex =
        stages.indexWhere((stage) => stage.pokemonId == currentId);
    if (currentIndex > 0) {
      return stages[currentIndex - 1];
    }
    return null;
  }
}

class EvolutionStage {
  final int pokemonId;
  final String name;
  final int minLevel;

  EvolutionStage({
    required this.pokemonId,
    required this.name,
    required this.minLevel,
  });

  factory EvolutionStage.fromJson(Map<String, dynamic> json) {
    try {
      return EvolutionStage(
        pokemonId: json['pokemon_id'] as int? ?? 0,
        name: json['name'] as String? ?? 'unknown',
        minLevel: json['min_level'] as int? ?? 1,
      );
    } catch (e) {
      throw FormatException('Error parsing evolution stage: $e');
    }
  }

  Map<String, dynamic> toJson() => {
        'pokemon_id': pokemonId,
        'name': name,
        'min_level': minLevel,
      };

  @override
  String toString() => json.encode(toJson());

  String getFormattedName() {
    return name.substring(0, 1).toUpperCase() + name.substring(1);
  }
}
