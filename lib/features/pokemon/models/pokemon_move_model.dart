// lib/features/pokemon/models/pokemon_move_model.dart

/// Detailed Pokemon move model for complete move information.
/// Contains all move properties, effects, and metadata.
library features.pokemon.models.pokemon_move_model;

import 'package:json_annotation/json_annotation.dart';

part 'pokemon_move_model.g.dart';

/// Move category types
enum MoveCategory {
  /// Physical moves (use Attack and Defense)
  physical,

  /// Special moves (use Sp. Attack and Sp. Defense)
  special,

  /// Status moves (no direct damage)
  status
}

/// Detailed Pokemon move model
@JsonSerializable()
class PokemonMoveDetail {
  /// Move ID
  final int id;

  /// Move name
  final String name;

  /// Move type (fire, water, etc.)
  final String type;

  /// Move category
  final MoveCategory category;

  /// Base power
  final int? power;

  /// Accuracy percentage
  final int? accuracy;

  /// Base PP (Power Points)
  final int pp;

  /// Move priority
  final int priority;

  /// Detailed effect description
  final String effect;

  /// Short effect description
  final String shortEffect;

  /// Effect chance percentage
  final int? effectChance;

  /// Target type (single, all adjacent, etc.)
  final String target;

  /// Critical hit rate bonus
  final int critRate;

  /// Drain percentage (if applicable)
  final int? drainPercentage;

  /// Healing percentage (if applicable)
  final int? healPercentage;

  /// Max number of hits (if applicable)
  final int? maxHits;

  /// Min number of hits (if applicable)
  final int? minHits;

  /// Max number of turns (if applicable)
  final int? maxTurns;

  /// Min number of turns (if applicable)
  final int? minTurns;

  /// Stats changed
  final List<MoveStatChange> statChanges;

  /// Move flags
  final List<MoveFlag> flags;

  /// Constructor
  const PokemonMoveDetail({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    this.power,
    this.accuracy,
    required this.pp,
    required this.priority,
    required this.effect,
    required this.shortEffect,
    this.effectChance,
    required this.target,
    required this.critRate,
    this.drainPercentage,
    this.healPercentage,
    this.maxHits,
    this.minHits,
    this.maxTurns,
    this.minTurns,
    required this.statChanges,
    required this.flags,
  });

  /// Create from JSON
  factory PokemonMoveDetail.fromJson(Map<String, dynamic> json) =>
      _$PokemonMoveDetailFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$PokemonMoveDetailToJson(this);

  /// Get display power
  String get displayPower => power?.toString() ?? '-';

  /// Get display accuracy
  String get displayAccuracy => accuracy != null ? '$accuracy%' : '-';

  /// Get effect with replaced effect chance
  String get formattedEffect => effectChance != null
      ? effect.replaceAll('$effectChance', '$effectChance%')
      : effect;

  /// Whether move has additional effect
  bool get hasAdditionalEffect => effectChance != null && effectChance! > 0;
}

/// Move stat change model
@JsonSerializable()
class MoveStatChange {
  /// Affected stat
  final String stat;

  /// Change amount
  final int change;

  /// Constructor
  const MoveStatChange({
    required this.stat,
    required this.change,
  });

  /// Create from JSON
  factory MoveStatChange.fromJson(Map<String, dynamic> json) =>
      _$MoveStatChangeFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$MoveStatChangeToJson(this);

  /// Get formatted change
  String get formattedChange => change >= 0 ? '+$change' : '$change';
}

/// Move flag model
@JsonSerializable()
class MoveFlag {
  /// Flag name
  final String name;

  /// Flag description
  final String description;

  /// Constructor
  const MoveFlag({
    required this.name,
    required this.description,
  });

  /// Create from JSON
  factory MoveFlag.fromJson(Map<String, dynamic> json) =>
      _$MoveFlagFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$MoveFlagToJson(this);
}

/// Move meta data model
@JsonSerializable()
class MoveMeta {
  /// Ailment caused
  final String? ailment;

  /// Ailment chance
  final int? ailmentChance;

  /// Category (damage, ailment, etc.)
  final String category;

  /// Critical hit rate
  final int critRate;

  /// Flinch chance
  final int? flinchChance;

  /// Stat chance
  final int? statChance;

  /// Constructor
  const MoveMeta({
    this.ailment,
    this.ailmentChance,
    required this.category,
    required this.critRate,
    this.flinchChance,
    this.statChance,
  });

  /// Create from JSON
  factory MoveMeta.fromJson(Map<String, dynamic> json) =>
      _$MoveMetaFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$MoveMetaToJson(this);
}
