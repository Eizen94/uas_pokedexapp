// lib/features/favorites/services/favorite_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class FavoriteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add to favorites
  Future<void> addToFavorites(String userId, String pokemonId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(pokemonId)
        .set({
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Remove from favorites
  Future<void> removeFromFavorites(String userId, String pokemonId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(pokemonId)
        .delete();
  }

  // Get user favorites
  Stream<QuerySnapshot> getUserFavorites(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots();
  }
}
