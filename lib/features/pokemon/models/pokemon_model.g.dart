// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pokemon_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PokemonModel _$PokemonModelFromJson(Map<String, dynamic> json) => PokemonModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      types: (json['types'] as List<dynamic>).map((e) => e as String).toList(),
      spriteUrl: json['spriteUrl'] as String,
      stats: PokemonStats.fromJson(json['stats'] as Map<String, dynamic>),
      height: (json['height'] as num).toInt(),
      weight: (json['weight'] as num).toInt(),
      baseExperience: (json['baseExperience'] as num).toInt(),
      species: json['species'] as String,
    );

Map<String, dynamic> _$PokemonModelToJson(PokemonModel instance) =>
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
    };

PokemonStats _$PokemonStatsFromJson(Map<String, dynamic> json) => PokemonStats(
      hp: (json['hp'] as num).toInt(),
      attack: (json['attack'] as num).toInt(),
      defense: (json['defense'] as num).toInt(),
      specialAttack: (json['specialAttack'] as num).toInt(),
      specialDefense: (json['specialDefense'] as num).toInt(),
      speed: (json['speed'] as num).toInt(),
    );

Map<String, dynamic> _$PokemonStatsToJson(PokemonStats instance) =>
    <String, dynamic>{
      'hp': instance.hp,
      'attack': instance.attack,
      'defense': instance.defense,
      'specialAttack': instance.specialAttack,
      'specialDefense': instance.specialDefense,
      'speed': instance.speed,
    };
