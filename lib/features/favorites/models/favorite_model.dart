// lib/features/favorites/models/favorite_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../pokemon/models/pokemon_model.dart';

class FavoriteModel {
  final String id;
  final String userId;
  final int pokemonId;
  final DateTime addedAt;
  final String pokemonName;
  final List<String> pokemonTypes;
  final String imageUrl;
  PokemonModel? pokemonData;

  FavoriteModel({
    required this.id,
    required this.userId,
    required this.pokemonId,
    required this.addedAt,
    required this.pokemonName,
    required this.pokemonTypes,
    required this.imageUrl,
    this.pokemonData,
  });

  // Create from Firestore document
  factory FavoriteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FavoriteModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      pokemonId: data['pokemonId'] as int? ?? 0,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pokemonName: data['pokemonName'] as String? ?? '',
      pokemonTypes: List<String>.from(data['pokemonTypes'] ?? []),
      imageUrl: data['imageUrl'] as String? ?? '',
    );
  }

  // Create from Pokemon model
  factory FavoriteModel.fromPokemon({
    required String userId,
    required PokemonModel pokemon,
  }) {
    return FavoriteModel(
      id: '${userId}_${pokemon.id}',
      userId: userId,
      pokemonId: pokemon.id,
      addedAt: DateTime.now(),
      pokemonName: pokemon.name,
      pokemonTypes: pokemon.types,
      imageUrl: pokemon.imageUrl,
      pokemonData: pokemon,
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'pokemonId': pokemonId,
      'addedAt': Timestamp.fromDate(addedAt),
      'pokemonName': pokemonName,
      'pokemonTypes': pokemonTypes,
      'imageUrl': imageUrl,
    };
  }

  // Create copy with modifications
  FavoriteModel copyWith({
    String? id,
    String? userId,
    int? pokemonId,
    DateTime? addedAt,
    String? pokemonName,
    List<String>? pokemonTypes,
    String? imageUrl,
    PokemonModel? pokemonData,
  }) {
    return FavoriteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      pokemonId: pokemonId ?? this.pokemonId,
      addedAt: addedAt ?? this.addedAt,
      pokemonName: pokemonName ?? this.pokemonName,
      pokemonTypes: pokemonTypes ?? this.pokemonTypes,
      imageUrl: imageUrl ?? this.imageUrl,
      pokemonData: pokemonData ?? this.pokemonData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          pokemonId == other.pokemonId;

  @override
  int get hashCode => id.hashCode ^ userId.hashCode ^ pokemonId.hashCode;

  @override
  String toString() {
    return 'FavoriteModel{id: $id, pokemonId: $pokemonId, pokemonName: $pokemonName}';
  }

  // Helper method to check if favorite is valid
  bool isValid() {
    return userId.isNotEmpty &&
        pokemonId > 0 &&
        pokemonName.isNotEmpty &&
        imageUrl.isNotEmpty;
  }

  // Helper method for debugging
  void debugPrint() {
    if (kDebugMode) {
      print('FavoriteModel:');
      print('  ID: $id');
      print('  User ID: $userId');
      print('  Pokemon ID: $pokemonId');
      print('  Pokemon Name: $pokemonName');
      print('  Added At: $addedAt');
      print('  Types: $pokemonTypes');
      print('  Has Pokemon Data: ${pokemonData != null}');
    }
  }
}
