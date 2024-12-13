// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pokemon_detail_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PokemonDetailModel _$PokemonDetailModelFromJson(Map<String, dynamic> json) =>
    PokemonDetailModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      types: (json['types'] as List<dynamic>).map((e) => e as String).toList(),
      spriteUrl: json['spriteUrl'] as String,
      stats: PokemonStats.fromJson(json['stats'] as Map<String, dynamic>),
      height: (json['height'] as num).toInt(),
      weight: (json['weight'] as num).toInt(),
      baseExperience: (json['baseExperience'] as num).toInt(),
      species: json['species'] as String,
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
      catchRate: (json['catchRate'] as num).toInt(),
      eggGroups:
          (json['eggGroups'] as List<dynamic>).map((e) => e as String).toList(),
      genderRatio: (json['genderRatio'] as num).toDouble(),
      generation: (json['generation'] as num).toInt(),
      habitat: json['habitat'] as String,
    );

Map<String, dynamic> _$PokemonDetailModelToJson(PokemonDetailModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'types': instance.types,
      'spriteUrl': instance.spriteUrl,
      'stats': instance.stats,
      'height': instance.height,
      'weight': instance.weight,
      'baseExperience': instance.baseExperience,
      'species': instance.species,
      'abilities': instance.abilities,
      'moves': instance.moves,
      'evolutionChain': instance.evolutionChain,
      'description': instance.description,
      'catchRate': instance.catchRate,
      'eggGroups': instance.eggGroups,
      'genderRatio': instance.genderRatio,
      'generation': instance.generation,
      'habitat': instance.habitat,
    };

PokemonAbility _$PokemonAbilityFromJson(Map<String, dynamic> json) =>
    PokemonAbility(
      name: json['name'] as String,
      description: json['description'] as String,
      isHidden: json['isHidden'] as bool,
    );

Map<String, dynamic> _$PokemonAbilityToJson(PokemonAbility instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'isHidden': instance.isHidden,
    };

PokemonMove _$PokemonMoveFromJson(Map<String, dynamic> json) => PokemonMove(
      name: json['name'] as String,
      type: json['type'] as String,
      power: (json['power'] as num?)?.toInt(),
      accuracy: (json['accuracy'] as num?)?.toInt(),
      pp: (json['pp'] as num).toInt(),
      description: json['description'] as String,
    );

Map<String, dynamic> _$PokemonMoveToJson(PokemonMove instance) =>
    <String, dynamic>{
      'name': instance.name,
      'type': instance.type,
      'power': instance.power,
      'accuracy': instance.accuracy,
      'pp': instance.pp,
      'description': instance.description,
    };

EvolutionStage _$EvolutionStageFromJson(Map<String, dynamic> json) =>
    EvolutionStage(
      pokemonId: (json['pokemonId'] as num).toInt(),
      name: json['name'] as String,
      spriteUrl: json['spriteUrl'] as String,
      level: (json['level'] as num?)?.toInt(),
      trigger: json['trigger'] as String?,
      item: json['item'] as String?,
    );

Map<String, dynamic> _$EvolutionStageToJson(EvolutionStage instance) =>
    <String, dynamic>{
      'pokemonId': instance.pokemonId,
      'name': instance.name,
      'spriteUrl': instance.spriteUrl,
      'level': instance.level,
      'trigger': instance.trigger,
      'item': instance.item,
    };
