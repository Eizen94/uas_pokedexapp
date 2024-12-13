// lib/features/pokemon/models/pokemon_detail_model.dart

import 'pokemon_model.dart';

/// Detailed Pokemon model that extends basic Pokemon information
/// with comprehensive data about evolution chain, moves, and characteristics
class PokemonDetailModel extends PokemonModel {
  // Evolution chain information
  final List<EvolutionStage> evolutionChain;

  // Detailed characteristics
  final String genus;
  final List<String> eggGroups;
  final int baseExperience;
  final int captureRate;
  final GrowthRate growthRate;
  final Gender gender;
  final List<String> habitats;

  // Battle information
  final List<PokemonMove> moves;
  final List<String> hiddenAbilities;
  final Map<String, double> typeEffectiveness;

  const PokemonDetailModel({
    required super.id,
    required super.name,
    required super.types,
    required super.imageUrl,
    required super.stats,
    required super.description,
    required super.height,
    required super.weight,
    required super.abilities,
    required super.category,
    required super.weaknesses,
    required super.generation,
    required this.evolutionChain,
    required this.genus,
    required this.eggGroups,
    required this.baseExperience,
    required this.captureRate,
    required this.growthRate,
    required this.gender,
    required this.habitats,
    required this.moves,
    required this.hiddenAbilities,
    required this.typeEffectiveness,
    super.isFavorite,
  });

  /// Create detailed Pokemon from JSON with proper validation
  factory PokemonDetailModel.fromJson(Map<String, dynamic> json) {
    try {
      final baseModel = PokemonModel.fromJson(json);

      return PokemonDetailModel(
        id: baseModel.id,
        name: baseModel.name,
        types: baseModel.types,
        imageUrl: baseModel.imageUrl,
        stats: baseModel.stats,
        description: baseModel.description,
        height: baseModel.height,
        weight: baseModel.weight,
        abilities: baseModel.abilities,
        category: baseModel.category,
        weaknesses: baseModel.weaknesses,
        generation: baseModel.generation,
        isFavorite: baseModel.isFavorite,
        evolutionChain: (json['evolution_chain'] as List)
            .map((e) => EvolutionStage.fromJson(e as Map<String, dynamic>))
            .toList(),
        genus: json['genus'] as String? ?? '',
        eggGroups: List<String>.from(json['egg_groups'] as List? ?? []),
        baseExperience: json['base_experience'] as int? ?? 0,
        captureRate: json['capture_rate'] as int? ?? 0,
        growthRate: GrowthRate.fromString(json['growth_rate'] as String? ?? ''),
        gender: Gender.fromJson(json['gender'] as Map<String, dynamic>? ?? {}),
        habitats: List<String>.from(json['habitats'] as List? ?? []),
        moves: (json['moves'] as List? ?? [])
            .map((e) => PokemonMove.fromJson(e as Map<String, dynamic>))
            .toList(),
        hiddenAbilities:
            List<String>.from(json['hidden_abilities'] as List? ?? []),
        typeEffectiveness: Map<String, double>.from(
          json['type_effectiveness'] as Map? ?? {},
        ),
      );
    } catch (e) {
      throw FormatException('Error parsing Pokemon detail data: $e');
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'evolution_chain': evolutionChain.map((e) => e.toJson()).toList(),
        'genus': genus,
        'egg_groups': eggGroups,
        'base_experience': baseExperience,
        'capture_rate': captureRate,
        'growth_rate': growthRate.value,
        'gender': gender.toJson(),
        'habitats': habitats,
        'moves': moves.map((e) => e.toJson()).toList(),
        'hidden_abilities': hiddenAbilities,
        'type_effectiveness': typeEffectiveness,
      };

  @override
  PokemonDetailModel copyWith({
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
    List<EvolutionStage>? evolutionChain,
    String? genus,
    List<String>? eggGroups,
    int? baseExperience,
    int? captureRate,
    GrowthRate? growthRate,
    Gender? gender,
    List<String>? habitats,
    List<PokemonMove>? moves,
    List<String>? hiddenAbilities,
    Map<String, double>? typeEffectiveness,
  }) {
    return PokemonDetailModel(
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
      evolutionChain: evolutionChain ?? this.evolutionChain,
      genus: genus ?? this.genus,
      eggGroups: eggGroups ?? this.eggGroups,
      baseExperience: baseExperience ?? this.baseExperience,
      captureRate: captureRate ?? this.captureRate,
      growthRate: growthRate ?? this.growthRate,
      gender: gender ?? this.gender,
      habitats: habitats ?? this.habitats,
      moves: moves ?? this.moves,
      hiddenAbilities: hiddenAbilities ?? this.hiddenAbilities,
      typeEffectiveness: typeEffectiveness ?? this.typeEffectiveness,
    );
  }
}

/// Evolution chain stage information
class EvolutionStage {
  final int stage;
  final String pokemonName;
  final String imageUrl;
  final List<EvolutionTrigger> triggers;

  const EvolutionStage({
    required this.stage,
    required this.pokemonName,
    required this.imageUrl,
    required this.triggers,
  });

  factory EvolutionStage.fromJson(Map<String, dynamic> json) {
    return EvolutionStage(
      stage: json['stage'] as int,
      pokemonName: json['pokemon_name'] as String,
      imageUrl: json['image_url'] as String,
      triggers: (json['triggers'] as List)
          .map((e) => EvolutionTrigger.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'pokemon_name': pokemonName,
        'image_url': imageUrl,
        'triggers': triggers.map((e) => e.toJson()).toList(),
      };
}

/// Evolution trigger information
class EvolutionTrigger {
  final String type;
  final String condition;
  final String? item;

  const EvolutionTrigger({
    required this.type,
    required this.condition,
    this.item,
  });

  factory EvolutionTrigger.fromJson(Map<String, dynamic> json) {
    return EvolutionTrigger(
      type: json['type'] as String,
      condition: json['condition'] as String,
      item: json['item'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'condition': condition,
        if (item != null) 'item': item,
      };
}

/// Pokemon move information
class PokemonMove {
  final String name;
  final String type;
  final int power;
  final int accuracy;
  final int pp;
  final String description;
  final String category;

  const PokemonMove({
    required this.name,
    required this.type,
    required this.power,
    required this.accuracy,
    required this.pp,
    required this.description,
    required this.category,
  });

  factory PokemonMove.fromJson(Map<String, dynamic> json) {
    return PokemonMove(
      name: json['name'] as String,
      type: json['type'] as String,
      power: json['power'] as int? ?? 0,
      accuracy: json['accuracy'] as int? ?? 0,
      pp: json['pp'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'power': power,
        'accuracy': accuracy,
        'pp': pp,
        'description': description,
        'category': category,
      };
}

/// Pokemon gender information
class Gender {
  final double maleRate;
  final double femaleRate;
  final bool genderless;

  const Gender({
    required this.maleRate,
    required this.femaleRate,
    required this.genderless,
  });

  factory Gender.fromJson(Map<String, dynamic> json) {
    return Gender(
      maleRate: (json['male_rate'] as num?)?.toDouble() ?? 0,
      femaleRate: (json['female_rate'] as num?)?.toDouble() ?? 0,
      genderless: json['genderless'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'male_rate': maleRate,
        'female_rate': femaleRate,
        'genderless': genderless,
      };
}

/// Pokemon growth rate enum
enum GrowthRate {
  slow('Slow'),
  mediumSlow('Medium Slow'),
  mediumFast('Medium Fast'),
  fast('Fast'),
  erratic('Erratic'),
  fluctuating('Fluctuating');

  final String value;
  const GrowthRate(this.value);

  static GrowthRate fromString(String value) {
    return GrowthRate.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => GrowthRate.mediumFast,
    );
  }
}
