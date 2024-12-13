// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pokemon_move_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PokemonMoveDetail _$PokemonMoveDetailFromJson(Map<String, dynamic> json) =>
    PokemonMoveDetail(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
      category: $enumDecode(_$MoveCategoryEnumMap, json['category']),
      power: (json['power'] as num?)?.toInt(),
      accuracy: (json['accuracy'] as num?)?.toInt(),
      pp: (json['pp'] as num).toInt(),
      priority: (json['priority'] as num).toInt(),
      effect: json['effect'] as String,
      shortEffect: json['shortEffect'] as String,
      effectChance: (json['effectChance'] as num?)?.toInt(),
      target: json['target'] as String,
      critRate: (json['critRate'] as num).toInt(),
      drainPercentage: (json['drainPercentage'] as num?)?.toInt(),
      healPercentage: (json['healPercentage'] as num?)?.toInt(),
      maxHits: (json['maxHits'] as num?)?.toInt(),
      minHits: (json['minHits'] as num?)?.toInt(),
      maxTurns: (json['maxTurns'] as num?)?.toInt(),
      minTurns: (json['minTurns'] as num?)?.toInt(),
      statChanges: (json['statChanges'] as List<dynamic>)
          .map((e) => MoveStatChange.fromJson(e as Map<String, dynamic>))
          .toList(),
      flags: (json['flags'] as List<dynamic>)
          .map((e) => MoveFlag.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PokemonMoveDetailToJson(PokemonMoveDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'category': _$MoveCategoryEnumMap[instance.category]!,
      'power': instance.power,
      'accuracy': instance.accuracy,
      'pp': instance.pp,
      'priority': instance.priority,
      'effect': instance.effect,
      'shortEffect': instance.shortEffect,
      'effectChance': instance.effectChance,
      'target': instance.target,
      'critRate': instance.critRate,
      'drainPercentage': instance.drainPercentage,
      'healPercentage': instance.healPercentage,
      'maxHits': instance.maxHits,
      'minHits': instance.minHits,
      'maxTurns': instance.maxTurns,
      'minTurns': instance.minTurns,
      'statChanges': instance.statChanges,
      'flags': instance.flags,
    };

const _$MoveCategoryEnumMap = {
  MoveCategory.physical: 'physical',
  MoveCategory.special: 'special',
  MoveCategory.status: 'status',
};

MoveStatChange _$MoveStatChangeFromJson(Map<String, dynamic> json) =>
    MoveStatChange(
      stat: json['stat'] as String,
      change: (json['change'] as num).toInt(),
    );

Map<String, dynamic> _$MoveStatChangeToJson(MoveStatChange instance) =>
    <String, dynamic>{
      'stat': instance.stat,
      'change': instance.change,
    };

MoveFlag _$MoveFlagFromJson(Map<String, dynamic> json) => MoveFlag(
      name: json['name'] as String,
      description: json['description'] as String,
    );

Map<String, dynamic> _$MoveFlagToJson(MoveFlag instance) => <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
    };

MoveMeta _$MoveMetaFromJson(Map<String, dynamic> json) => MoveMeta(
      ailment: json['ailment'] as String?,
      ailmentChance: (json['ailmentChance'] as num?)?.toInt(),
      category: json['category'] as String,
      critRate: (json['critRate'] as num).toInt(),
      flinchChance: (json['flinchChance'] as num?)?.toInt(),
      statChance: (json['statChance'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MoveMetaToJson(MoveMeta instance) => <String, dynamic>{
      'ailment': instance.ailment,
      'ailmentChance': instance.ailmentChance,
      'category': instance.category,
      'critRate': instance.critRate,
      'flinchChance': instance.flinchChance,
      'statChance': instance.statChance,
    };
