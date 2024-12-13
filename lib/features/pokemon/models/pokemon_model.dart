// lib/features/pokemon/models/pokemon_model.dart

/// Pokemon model to represent Pokemon data.
/// Contains basic Pokemon information and stats.
library features.pokemon.models.pokemon_model;

import 'package:json_annotation/json_annotation.dart';

part 'pokemon_model.g.dart';

/// Pokemon model class
@JsonSerializable()
class PokemonModel {
  /// Pokemon ID
  final int id;

  /// Pokemon name
  final String name;

  /// Pokemon types
  final List<String> types;

  /// Pokemon sprite URL
  final String spriteUrl;

  /// Base stats
  final PokemonStats stats;

  /// Height in decimeters
  final int height;

  /// Weight in hectograms
  final int weight;

  /// Base experience
  final int baseExperience;

  /// Species name
  final String species;

  /// Constructor
  const PokemonModel({
    required this.id,
    required this.name,
    required this.types,
    required this.spriteUrl,
    required this.stats,
    required this.height,
    required this.weight,
    required this.baseExperience,
    required this.species,
  });

  /// Create from JSON
  factory PokemonModel.fromJson(Map<String, dynamic> json) =>
      _$PokemonModelFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$PokemonModelToJson(this);

  /// Create copy with updated fields
  PokemonModel copyWith({
    String? name,
    List<String>? types,
    String? spriteUrl,
    PokemonStats? stats,
    int? height,
    int? weight,
    int? baseExperience,
    String? species,
  }) {
    return PokemonModel(
      id: id,
      name: name ?? this.name,
      types: types ?? this.types,
      spriteUrl: spriteUrl ?? this.spriteUrl,
      stats: stats ?? this.stats,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      baseExperience: baseExperience ?? this.baseExperience,
      species: species ?? this.species,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PokemonModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() => 'PokemonModel(id: $id, name: $name)';
}

/// Pokemon stats model
@JsonSerializable()
class PokemonStats {
  /// HP stat
  final int hp;

  /// Attack stat
  final int attack;

  /// Defense stat
  final int defense;

  /// Special Attack stat
  final int specialAttack;

  /// Special Defense stat
  final int specialDefense;

  /// Speed stat
  final int speed;

  /// Constructor
  const PokemonStats({
    required this.hp,
    required this.attack,
    required this.defense,
    required this.specialAttack,
    required this.specialDefense,
    required this.speed,
  });

  /// Create from JSON
  factory PokemonStats.fromJson(Map<String, dynamic> json) =>
      _$PokemonStatsFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$PokemonStatsToJson(this);

  /// Get total stats
  int get total =>
      hp + attack + defense + specialAttack + specialDefense + speed;

  /// Create copy with updated fields
  PokemonStats copyWith({
    int? hp,
    int? attack,
    int? defense,
    int? specialAttack,
    int? specialDefense,
    int? speed,
  }) {
    return PokemonStats(
      hp: hp ?? this.hp,
      attack: attack ?? this.attack,
      defense: defense ?? this.defense,
      specialAttack: specialAttack ?? this.specialAttack,
      specialDefense: specialDefense ?? this.specialDefense,
      speed: speed ?? this.speed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PokemonStats &&
          runtimeType == other.runtimeType &&
          hp == other.hp &&
          attack == other.attack &&
          defense == other.defense &&
          specialAttack == other.specialAttack &&
          specialDefense == other.specialDefense &&
          speed == other.speed;

  @override
  int get hashCode =>
      hp.hashCode ^
      attack.hashCode ^
      defense.hashCode ^
      specialAttack.hashCode ^
      specialDefense.hashCode ^
      speed.hashCode;
}
