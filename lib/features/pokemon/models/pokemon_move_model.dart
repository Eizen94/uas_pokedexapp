// lib/features/pokemon/models/pokemon_move_model.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';

class PokemonMove {
  final int id;
  final String name;
  final String type;
  final String category;
  final int power;
  final int accuracy;
  final int pp;
  final String effect;
  final int effectChance;
  final String target;
  final int priority;
  final String damageClass;

  PokemonMove({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.power,
    required this.accuracy,
    required this.pp,
    required this.effect,
    required this.effectChance,
    required this.target,
    required this.priority,
    required this.damageClass,
  });

  factory PokemonMove.fromJson(Map<String, dynamic> json) {
    try {
      return PokemonMove(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        type: json['type']?['name'] as String? ?? 'normal',
        category: _determineMoveCategory(json),
        power: json['power'] as int? ?? 0,
        accuracy: json['accuracy'] as int? ?? 0,
        pp: json['pp'] as int? ?? 0,
        effect: _getEffectText(json),
        effectChance: json['effect_chance'] as int? ?? 0,
        target: json['target']?['name'] as String? ?? 'selected-pokemon',
        priority: json['priority'] as int? ?? 0,
        damageClass: json['damage_class']?['name'] as String? ?? 'physical',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing move data: $e');
      }
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': {'name': type},
        'power': power,
        'accuracy': accuracy,
        'pp': pp,
        'effect': effect,
        'effect_chance': effectChance,
        'target': {'name': target},
        'priority': priority,
        'damage_class': {'name': damageClass},
      };

  static String _determineMoveCategory(Map<String, dynamic> json) {
    final damageClass = json['damage_class']?['name'] as String?;
    if (damageClass == null) return 'status';

    switch (damageClass.toLowerCase()) {
      case 'physical':
        return 'physical';
      case 'special':
        return 'special';
      default:
        return 'status';
    }
  }

  static String _getEffectText(Map<String, dynamic> json) {
    try {
      final effectEntries = json['effect_entries'] as List?;
      if (effectEntries == null || effectEntries.isEmpty) {
        return json['effect'] as String? ?? '';
      }

      final englishEffect = effectEntries.firstWhere(
        (entry) => entry['language']?['name'] == 'en',
        orElse: () => {'effect': ''},
      );

      return englishEffect['effect'] as String? ?? '';
    } catch (e) {
      if (kDebugMode) {
        print('Error getting effect text: $e');
      }
      return '';
    }
  }

  // Helper methods for move information
  bool get isPhysical => damageClass == 'physical';
  bool get isSpecial => damageClass == 'special';
  bool get isStatus => damageClass == 'status';

  bool get hasPower => power > 0;
  bool get hasAccuracy => accuracy > 0;
  bool get hasEffect => effectChance > 0;

  String get formattedName {
    return name
        .split('-')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String get formattedEffect {
    if (effectChance > 0) {
      return effect.replaceAll('\$effect_chance', effectChance.toString());
    }
    return effect;
  }

  // Comparison methods for sorting
  static int compareByName(PokemonMove a, PokemonMove b) {
    return a.name.compareTo(b.name);
  }

  static int compareByPower(PokemonMove a, PokemonMove b) {
    if (a.power == b.power) return compareByName(a, b);
    return b.power.compareTo(a.power);
  }

  static int compareByAccuracy(PokemonMove a, PokemonMove b) {
    if (a.accuracy == b.accuracy) return compareByName(a, b);
    return b.accuracy.compareTo(a.accuracy);
  }

  static int compareByPP(PokemonMove a, PokemonMove b) {
    if (a.pp == b.pp) return compareByName(a, b);
    return b.pp.compareTo(a.pp);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PokemonMove && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => json.encode(toJson());

  PokemonMove copyWith({
    int? id,
    String? name,
    String? type,
    String? category,
    int? power,
    int? accuracy,
    int? pp,
    String? effect,
    int? effectChance,
    String? target,
    int? priority,
    String? damageClass,
  }) {
    return PokemonMove(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      category: category ?? this.category,
      power: power ?? this.power,
      accuracy: accuracy ?? this.accuracy,
      pp: pp ?? this.pp,
      effect: effect ?? this.effect,
      effectChance: effectChance ?? this.effectChance,
      target: target ?? this.target,
      priority: priority ?? this.priority,
      damageClass: damageClass ?? this.damageClass,
    );
  }
}
