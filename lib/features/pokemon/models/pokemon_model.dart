// lib/features/pokemon/models/pokemon_model.dart

import 'dart:convert';

class PokemonModel {
  final int id;
  final String name;
  final String imageUrl;
  final List<String> types;
  final int height;
  final int weight;
  final String? sprite;
  final Map<String, dynamic> stats;

  PokemonModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.types,
    required this.height,
    required this.weight,
    this.sprite,
    Map<String, dynamic>? stats,
  }) : stats = stats ?? {};

  factory PokemonModel.fromJson(Map<String, dynamic> json) {
    try {
      // ID validation
      final id = json['id'];
      if (id == null || id is! int) {
        throw FormatException('Invalid or missing Pokemon ID');
      }

      // Extract types safely
      final typesList = (json['types'] as List?)?.map((type) {
            if (type is Map<String, dynamic> &&
                type['type'] is Map<String, dynamic> &&
                type['type']['name'] is String) {
              return type['type']['name'] as String;
            }
            return 'unknown';
          }).toList() ??
          ['unknown'];

      // Generate image URL
      final imageUrl =
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';

      // Get sprite (front default) if available
      final sprite = json['sprites']?['front_default'] as String?;

      // Extract base stats
      final stats = <String, dynamic>{};
      if (json['stats'] is List) {
        for (final stat in json['stats'] as List) {
          if (stat is Map<String, dynamic> &&
              stat['stat'] is Map<String, dynamic> &&
              stat['stat']['name'] is String &&
              stat['base_stat'] is int) {
            stats[stat['stat']['name'] as String] = stat['base_stat'];
          }
        }
      }

      return PokemonModel(
        id: id,
        name: (json['name'] as String?)?.toLowerCase() ?? 'unknown',
        imageUrl: imageUrl,
        types: typesList,
        height: (json['height'] as num?)?.toInt() ?? 0,
        weight: (json['weight'] as num?)?.toInt() ?? 0,
        sprite: sprite,
        stats: stats,
      );
    } catch (e) {
      throw FormatException('Error parsing Pokemon data: $e');
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imageUrl': imageUrl,
        'types': types,
        'height': height,
        'weight': weight,
        'sprite': sprite,
        'stats': stats,
      };

  @override
  String toString() => json.encode(toJson());

  PokemonModel copyWith({
    int? id,
    String? name,
    String? imageUrl,
    List<String>? types,
    int? height,
    int? weight,
    String? sprite,
    Map<String, dynamic>? stats,
  }) {
    return PokemonModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      types: types ?? this.types,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      sprite: sprite ?? this.sprite,
      stats: stats ?? this.stats,
    );
  }

  // Helper methods
  double getHeightInMeters() => height / 10;
  double getWeightInKg() => weight / 10;

  String getFormattedHeight() {
    final meters = getHeightInMeters();
    return '${meters.toStringAsFixed(1)}m';
  }

  String getFormattedWeight() {
    final kg = getWeightInKg();
    return '${kg.toStringAsFixed(1)}kg';
  }

  String getFormattedName() {
    return name.substring(0, 1).toUpperCase() + name.substring(1);
  }

  String getFormattedId() {
    return '#${id.toString().padLeft(3, '0')}';
  }

  int getBaseStat(String statName) {
    return stats[statName] ?? 0;
  }

  // Type checking methods
  bool hasType(String type) {
    return types.contains(type.toLowerCase());
  }

  bool isMultiType() {
    return types.length > 1;
  }

  String getPrimaryType() {
    return types.isNotEmpty ? types[0] : 'unknown';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PokemonModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
