// lib/features/favorites/models/favorite_model.dart

/// Favorite Pokemon model to manage user's favorite Pokemon.
/// Handles favorite Pokemon data and metadata.
library features.favorites.models.favorite_model;

import 'package:json_annotation/json_annotation.dart';
import '../../pokemon/models/pokemon_model.dart';

part 'favorite_model.g.dart';

/// Favorite Pokemon model
@JsonSerializable()
class FavoriteModel {
  /// Unique identifier
  final String id;

  /// User ID
  final String userId;

  /// Pokemon data
  final PokemonModel pokemon;

  /// Added timestamp
  final DateTime addedAt;

  /// Custom note
  final String? note;

  /// Custom nickname
  final String? nickname;

  /// Team position (if part of team)
  final int? teamPosition;

  /// Constructor
  const FavoriteModel({
    required this.id,
    required this.userId,
    required this.pokemon,
    required this.addedAt,
    this.note,
    this.nickname,
    this.teamPosition,
  });

  /// Create from JSON
  factory FavoriteModel.fromJson(Map<String, dynamic> json) =>
      _$FavoriteModelFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$FavoriteModelToJson(this);

  /// Create from Pokemon
  factory FavoriteModel.fromPokemon({
    required String userId,
    required PokemonModel pokemon,
    String? note,
    String? nickname,
    int? teamPosition,
  }) {
    return FavoriteModel(
      id: '${userId}_${pokemon.id}',
      userId: userId,
      pokemon: pokemon,
      addedAt: DateTime.now(),
      note: note,
      nickname: nickname,
      teamPosition: teamPosition,
    );
  }

  /// Create copy with updated fields
  FavoriteModel copyWith({
    String? note,
    String? nickname,
    int? teamPosition,
  }) {
    return FavoriteModel(
      id: id,
      userId: userId,
      pokemon: pokemon,
      addedAt: addedAt,
      note: note ?? this.note,
      nickname: nickname ?? this.nickname,
      teamPosition: teamPosition ?? this.teamPosition,
    );
  }

  /// Convert to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'pokemonId': pokemon.id,
      'addedAt': addedAt,
      if (note != null) 'note': note,
      if (nickname != null) 'nickname': nickname,
      if (teamPosition != null) 'teamPosition': teamPosition,
    };
  }

  /// Create from Firestore data
  static Future<FavoriteModel> fromFirestore({
    required Map<String, dynamic> data,
    required PokemonModel pokemon,
  }) async {
    return FavoriteModel(
      id: data['id'] as String,
      userId: data['userId'] as String,
      pokemon: pokemon,
      addedAt: (data['addedAt'] as Timestamp).toDate(),
      note: data['note'] as String?,
      nickname: data['nickname'] as String?,
      teamPosition: data['teamPosition'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FavoriteModel('
      'id: $id, '
      'pokemon: ${pokemon.name}, '
      'nickname: $nickname)';
}

/// Team member model for Pokemon team
@JsonSerializable()
class TeamMemberModel {
  /// Position in team (1-6)
  final int position;

  /// Favorite Pokemon reference
  final FavoriteModel favorite;

  /// Custom moves for team
  final List<String> selectedMoves;

  /// Constructor
  const TeamMemberModel({
    required this.position,
    required this.favorite,
    required this.selectedMoves,
  });

  /// Create from JSON
  factory TeamMemberModel.fromJson(Map<String, dynamic> json) =>
      _$TeamMemberModelFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$TeamMemberModelToJson(this);

  /// Convert to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'position': position,
      'favoriteId': favorite.id,
      'selectedMoves': selectedMoves,
    };
  }
}
