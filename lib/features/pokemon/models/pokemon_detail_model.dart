// lib/features/pokemon/models/pokemon_detail_model.dart

import 'dart:convert';
import 'pokemon_model.dart';

class PokemonDetailModel extends PokemonModel {
  final List<Ability> abilities;
  final List<Stat> stats;
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
    required this.stats,
    required this.moves,
    required this.species,
    this.evolution,
  });

  factory PokemonDetailModel.fromJson(Map<String, dynamic> json) {
    return PokemonDetailModel(
      id: json['id'],
      name: json['name'],
      imageUrl:
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${json['id']}.png',
      types: (json['types'] as List)
          .map((type) => type['type']['name'] as String)
          .toList(),
      height: json['height'],
      weight: json['weight'],
      abilities: (json['abilities'] as List)
          .map((ability) => Ability.fromJson(ability))
          .toList(),
      stats:
          (json['stats'] as List).map((stat) => Stat.fromJson(stat)).toList(),
      moves: (json['moves'] as List)
          .map((move) => move['move']['name'] as String)
          .toList(),
      species: json['species']['name'],
      evolution: json['evolution'] != null
          ? Evolution.fromJson(json['evolution'])
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'abilities': abilities.map((ability) => ability.toJson()).toList(),
        'stats': stats.map((stat) => stat.toJson()).toList(),
        'moves': moves,
        'species': species,
        'evolution': evolution?.toJson(),
      };
}

class Ability {
  final String name;
  final bool isHidden;

  Ability({required this.name, required this.isHidden});

  factory Ability.fromJson(Map<String, dynamic> json) {
    return Ability(
      name: json['ability']['name'],
      isHidden: json['is_hidden'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'is_hidden': isHidden,
      };
}

class Stat {
  final String name;
  final int baseStat;
  final int effort;

  Stat({required this.name, required this.baseStat, required this.effort});

  factory Stat.fromJson(Map<String, dynamic> json) {
    return Stat(
      name: json['stat']['name'],
      baseStat: json['base_stat'],
      effort: json['effort'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'base_stat': baseStat,
        'effort': effort,
      };
}

class Evolution {
  final int chainId;
  final List<EvolutionStage> stages;

  Evolution({required this.chainId, required this.stages});

  factory Evolution.fromJson(Map<String, dynamic> json) {
    return Evolution(
      chainId: json['chain_id'],
      stages: (json['stages'] as List)
          .map((stage) => EvolutionStage.fromJson(stage))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'chain_id': chainId,
        'stages': stages.map((stage) => stage.toJson()).toList(),
      };
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
    return EvolutionStage(
      pokemonId: json['pokemon_id'],
      name: json['name'],
      minLevel: json['min_level'],
    );
  }

  Map<String, dynamic> toJson() => {
        'pokemon_id': pokemonId,
        'name': name,
        'min_level': minLevel,
      };
}
