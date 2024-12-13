// lib/features/pokemon/models/pokemon_detail_model.dart

/// Pokemon detail model to represent detailed Pokemon information.
/// Contains complete Pokemon data including moves, abilities, and evolution chain.
library features.pokemon.models.pokemon_detail_model;

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

  /// Create from JSON
  factory PokemonDetailModel.fromJson(Map<String, dynamic> json) => 
      _$PokemonDetailModelFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PokemonDetailModelToJson(this);

  /// Create copy with updated fields
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
  factory PokemonAbility.fromJson(Map<String, dynamic> json) => 
      _$PokemonAbilityFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$PokemonAbilityToJson(this);
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
  factory PokemonMove.fromJson(Map<String, dynamic> json) => 
      _$PokemonMoveFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$PokemonMoveToJson(this);
}

/// Evolution stage model
@JsonSerializable()
class EvolutionStage {
  /// Pokemon ID
  final int pokemonId;

  /// Pokemon name
  final String name;

  /// Sprite URL
  final String spriteUrl;

  /// Evolution level
  final int? level;

  /// Evolution trigger
  final String? trigger;

  /// Evolution item
  final String? item;

  /// Constructor
  const EvolutionStage({
    required this.pokemonId,
    required this.name,
    required this.spriteUrl,
    this.level,
    this.trigger,
    this.item,
  });

  /// Create from JSON
  factory EvolutionStage.fromJson(Map<String, dynamic> json) => 
      _$EvolutionStageFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$EvolutionStageToJson(this);
}