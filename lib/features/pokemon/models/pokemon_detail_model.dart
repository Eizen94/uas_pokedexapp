// lib/features/pokemon/models/pokemon_detail_model.dart

/// Pokemon detail model to represent detailed Pokemon information.
/// Contains complete Pokemon data including moves, abilities, and evolution chain.
library;

import 'package:json_annotation/json_annotation.dart';
import 'pokemon_model.dart';

part 'pokemon_detail_model.g.dart';

/// Pokemon detail model class
@JsonSerializable()
class PokemonDetailModel extends PokemonModel {
  /// Pokemon abilities
  final List<PokemonAbility> abilities;

  /// Pokemon moves
  final List<PokemonMove> moves;

  /// Evolution chain
  final List<EvolutionStage> evolutionChain;

  /// Pokemon description
  final String description;

  /// Pokemon catch rate
  final int catchRate;

  /// Pokemon egg groups
  final List<String> eggGroups;

  /// Pokemon gender ratio (female percentage)
  final double genderRatio;
  
  /// Pokemon generation number
  final int generation;

  /// Pokemon habitat
  final String habitat;

  /// Constructor
  const PokemonDetailModel({
    required super.id,
    required super.name,
    required super.types,
    required super.spriteUrl,
    required super.stats,
    required super.height,
    required super.weight,
    required super.baseExperience,
    required super.species,
    required this.abilities,
    required this.moves,
    required this.evolutionChain,
    required this.description,
    required this.catchRate,
    required this.eggGroups,
    required this.genderRatio,
    required this.generation,
    required this.habitat,
  });

  /// Create from JSON with proper typing
  factory PokemonDetailModel.fromJson(Map<String, dynamic> json) {
    // First create base pokemon model
    final basePokemon = PokemonModel.fromJson(json);
    
    return PokemonDetailModel(
      id: basePokemon.id,
      name: basePokemon.name,
      types: basePokemon.types,
      spriteUrl: basePokemon.spriteUrl,
      stats: basePokemon.stats,
      height: basePokemon.height,
      weight: basePokemon.weight,
      baseExperience: basePokemon.baseExperience,
      species: basePokemon.species,
      abilities: (json['abilities'] as List<dynamic>)
          .map((e) => PokemonAbility.fromJson(e as Map<String, dynamic>))
          .toList(),
      moves: (json['moves'] as List<dynamic>)
          .map((e) => PokemonMove.fromJson(e as Map<String, dynamic>))
          .toList(),
      evolutionChain: (json['evolutionChain'] as List<dynamic>)
          .map((e) => EvolutionStage.fromJson(e as Map<String, dynamic>))
          .toList(),
      description: json['description'] as String,
      catchRate: json['catchRate'] as int,
      eggGroups: (json['eggGroups'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      genderRatio: (json['genderRatio'] as num).toDouble(),
      generation: json['generation'] as int,
      habitat: json['habitat'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    
    return {
      ...baseJson,
      'abilities': abilities.map((e) => e.toJson()).toList(),
      'moves': moves.map((e) => e.toJson()).toList(),
      'evolutionChain': evolutionChain.map((e) => e.toJson()).toList(),
      'description': description,
      'catchRate': catchRate,
      'eggGroups': eggGroups,
      'genderRatio': genderRatio,
      'generation': generation,
      'habitat': habitat,
    };
  }

  @override
  PokemonDetailModel copyWith({
    int? id,
    String? name,
    List<String>? types,
    String? spriteUrl,
    PokemonStats? stats,
    int? height,
    int? weight,
    int? baseExperience, 
    String? species,
    List<PokemonAbility>? abilities,
    List<PokemonMove>? moves,
    List<EvolutionStage>? evolutionChain,
    String? description,
    int? catchRate,
    List<String>? eggGroups,
    double? genderRatio,
    int? generation,
    String? habitat,
  }) {
    return PokemonDetailModel(
      id: id ?? this.id,
      name: name ?? this.name,
      types: types ?? this.types,
      spriteUrl: spriteUrl ?? this.spriteUrl,
      stats: stats ?? this.stats,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      baseExperience: baseExperience ?? this.baseExperience,
      species: species ?? this.species,
      abilities: abilities ?? this.abilities,  
      moves: moves ?? this.moves,
      evolutionChain: evolutionChain ?? this.evolutionChain,
      description: description ?? this.description,
      catchRate: catchRate ?? this.catchRate,
      eggGroups: eggGroups ?? this.eggGroups,
      genderRatio: genderRatio ?? this.genderRatio,
      generation: generation ?? this.generation,
      habitat: habitat ?? this.habitat,
    );
  }
}

/// Pokemon ability model
@JsonSerializable()
class PokemonAbility {
  /// Ability name
  final String name;

  /// Ability description 
  final String description;

  /// Whether this is a hidden ability
  final bool isHidden;

  /// Constructor
  const PokemonAbility({
    required this.name,
    required this.description, 
    required this.isHidden,
  });

  /// Create from JSON
  factory PokemonAbility.fromJson(Map<String, dynamic> json) {
    final ability = json['ability'] as Map<String, dynamic>;
    final isHidden = json['is_hidden'] as bool;
    
    return PokemonAbility(
      name: ability['name'] as String,
      // Description will be set later from ability details API
      description: json['description'] as String? ?? '',
      isHidden: isHidden,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'ability': {'name': name},
    'description': description,
    'is_hidden': isHidden,
  };
}

/// Pokemon move model
@JsonSerializable() 
class PokemonMove {
  /// Move name
  final String name;

  /// Move type
  final String type;
  
  /// Move power
  final int? power;

  /// Move accuracy
  final int? accuracy;
  
  /// Move PP (Power Points)
  final int pp;

  /// Move description
  final String description;

  /// Constructor
  const PokemonMove({
    required this.name,
    required this.type,
    this.power,
    this.accuracy,
    required this.pp,
    required this.description,
  });

  /// Create from JSON
  factory PokemonMove.fromJson(Map<String, dynamic> json) {
    final move = json['move'] as Map<String, dynamic>;
    return PokemonMove(
      name: move['name'] as String,
      // These fields will be set later from move details API
      type: json['type'] as String? ?? '',
      power: json['power'] as int?,
      accuracy: json['accuracy'] as int?,
      pp: json['pp'] as int? ?? 0,
      description: json['description'] as String? ?? '',
    );
  }

  /// Convert to JSON 
  Map<String, dynamic> toJson() => {
    'move': {'name': name},
    'type': type,
    'power': power,
    'accuracy': accuracy,
    'pp': pp,
    'description': description,
  };
}

/// Evolution stage model
@JsonSerializable()
class EvolutionStage {
  /// Pokemon ID
  final int pokemonId;

  /// Pokemon name