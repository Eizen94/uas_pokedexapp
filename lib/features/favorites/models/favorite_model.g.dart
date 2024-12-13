// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FavoriteModel _$FavoriteModelFromJson(Map<String, dynamic> json) =>
    FavoriteModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      pokemon: PokemonModel.fromJson(json['pokemon'] as Map<String, dynamic>),
      addedAt: DateTime.parse(json['addedAt'] as String),
      note: json['note'] as String?,
      nickname: json['nickname'] as String?,
      teamPosition: (json['teamPosition'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FavoriteModelToJson(FavoriteModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'pokemon': instance.pokemon,
      'addedAt': instance.addedAt.toIso8601String(),
      'note': instance.note,
      'nickname': instance.nickname,
      'teamPosition': instance.teamPosition,
    };

TeamMemberModel _$TeamMemberModelFromJson(Map<String, dynamic> json) =>
    TeamMemberModel(
      position: (json['position'] as num).toInt(),
      favorite:
          FavoriteModel.fromJson(json['favorite'] as Map<String, dynamic>),
      selectedMoves: (json['selectedMoves'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$TeamMemberModelToJson(TeamMemberModel instance) =>
    <String, dynamic>{
      'position': instance.position,
      'favorite': instance.favorite,
      'selectedMoves': instance.selectedMoves,
    };
