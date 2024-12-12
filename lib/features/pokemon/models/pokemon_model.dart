// lib/features/pokemon/models/pokemon_model.dart

import 'dart:convert';

/// Model class representing a Pokemon with all its basic information.
/// Handles proper data validation and type safety.
class PokemonModel {
  final int id;
  final String name;
  final List<String> types;
  final String imageUrl;
  final PokemonStats stats;
  final String description;
  final double height; // in meters
  final double weight; // in kg
  final List<String> abilities;
  final String category;
  final List<String> weaknesses;
  final String generation;
  final bool isFavorite;

  const PokemonModel({
    required this.id,
    required this.name,
    required this.types,
    required this.imageUrl,
    required this.stats,
    required this.description,
    required this.height,
    required this.weight,
    required this.abilities,
    required this.category,
    required this.weaknesses,
    required this.generation,
    this.isFavorite = false,
  });

  /// Create Pokemon from JSON with proper validation
  factory PokemonModel.fromJson(Map<String, dynamic> json) {
    try {
      return PokemonModel(
        id: json['id'] as int,
        name: json['name'] as String,
        types: List<String>.from(json['types'] as List),
        imageUrl: json['sprites']['other']['official-artwork']['front_default']
            as String,
        stats: PokemonStats.fromJson(json['stats'] as List<dynamic>),
        description: json['description'] as String? ?? '',
        height: (json['height'] as num).toDouble() / 10, // Convert to meters
        weight: (json['weight'] as num).toDouble() / 10, // Convert to kg
        abilities: List<String>.from(
            json['abilities'].map((a) => a['ability']['name'])),
        category: json['category'] as String? ?? 'Unknown',
        weaknesses: List<String>.from(json['weaknesses'] as List? ?? []),
        generation: json['generation'] as String? ?? 'Unknown',
        isFavorite: json['isFavorite'] as bool? ?? false,
      );
    } catch (e) {
      throw FormatException('Error parsing Pokemon data: $e');
    }
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'types': types,
        'imageUrl': imageUrl,
        'stats': stats.toJson(),
        'description': description,
        'height': height * 10, // Convert back to decimeters
        'weight': weight * 10, // Convert back to hectograms
        'abilities': abilities,
        'category': category,
        'weaknesses': weaknesses,
        'generation': generation,
        'isFavorite': isFavorite,
      };

  /// Create copy with updated fields
  PokemonModel copyWith({
    int? id,
    String? name,
    List<String>? types,
    String? imageUrl,
    PokemonStats? stats,
    String? description,
    double? height,
    double? weight,
    List<String>? abilities,
    String? category,
    List<String>? weaknesses,
    String? generation,
    bool? isFavorite,
  }) {
    return PokemonModel(
      id: id ?? this.id,
      name: name ?? this.name,
      types: types ?? this.types,
      imageUrl: imageUrl ?? this.imageUrl,
      stats: stats ?? this.stats,
      description: description ?? this.description,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      abilities: abilities ?? this.abilities,
      category: category ?? this.category,
      weaknesses: weaknesses ?? this.weaknesses,
      generation: generation ?? this.generation,
      isFavorite: isFavorite ?? this.isFavorite,
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
  String toString() => 'Pokemon(id: $id, name: $name)';
}

/// Stats for a Pokemon with proper validation
class PokemonStats {
  final int hp;
  final int attack;
  final int defense;
  final int specialAttack;
  final int specialDefense;
  final int speed;

  const PokemonStats({
    required this.hp,
    required this.attack,
    required this.defense,
    required this.specialAttack,
    required this.specialDefense,
    required this.speed,
  });

  /// Create stats from JSON array with validation
  factory PokemonStats.fromJson(List<dynamic> json) {
    try {
      return PokemonStats(
        hp: json[0]['base_stat'] as int,
        attack: json[1]['base_stat'] as int,
        defense: json[2]['base_stat'] as int,
        specialAttack: json[3]['base_stat'] as int,
        specialDefense: json[4]['base_stat'] as int,
        speed: json[5]['base_stat'] as int,
      );
    } catch (e) {
      throw FormatException('Error parsing Pokemon stats: $e');
    }
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
        'hp': hp,
        'attack': attack,
        'defense': defense,
        'specialAttack': specialAttack,
        'specialDefense': specialDefense,
        'speed': speed,
      };

  /// Get total stats value
  int get total =>
      hp + attack + defense + specialAttack + specialDefense + speed;

  /// Get average stats value
  double get average => total / 6;

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

  @override
  String toString() =>
      'PokemonStats(hp: $hp, attack: $attack, defense: $defense)';
}
