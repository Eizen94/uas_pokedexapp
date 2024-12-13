// lib/features/favorites/services/favorite_service.dart

/// Favorite service to manage user's favorite Pokemon.
/// Handles favorite operations and synchronization with Firestore.
library features.favorites.services.favorite_service;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/utils/monitoring_manager.dart';
import '../../../core/utils/connectivity_manager.dart';
import '../../../core/utils/offline_operation.dart';
import '../../pokemon/models/pokemon_model.dart';
import '../models/favorite_model.dart';

/// Favorite service error messages
class FavoriteServiceError {
  static const String notFound = 'Favorite not found';
  static const String alreadyExists = 'Pokemon already in favorites';
  static const String saveFailed = 'Failed to save favorite';
  static const String deleteFailed = 'Failed to delete favorite';
  static const String networkError = 'Network error occurred';
  static const String maxTeamSize = 'Maximum team size reached (6 Pokemon)';
}

/// Service class for managing favorites
class FavoriteService {
  final FirebaseConfig _firebaseConfig;
  final ConnectivityManager _connectivityManager;
  final MonitoringManager _monitoringManager;
  final OfflineOperationManager _offlineManager;

  FavoriteService._({
    required FirebaseConfig firebaseConfig,
    required ConnectivityManager connectivityManager,
    required MonitoringManager monitoringManager,
    required OfflineOperationManager offlineManager,
  })  : _firebaseConfig = firebaseConfig,
        _connectivityManager = connectivityManager,
        _monitoringManager = monitoringManager,
        _offlineManager = offlineManager;

  static Future<FavoriteService> initialize() async {
    final offlineManager = await OfflineOperationManager.initialize();

    return FavoriteService._(
      firebaseConfig: FirebaseConfig(),
      connectivityManager: ConnectivityManager(),
      monitoringManager: MonitoringManager(),
      offlineManager: offlineManager,
    );
  }

  /// Get user's favorites stream
  Stream<List<FavoriteModel>> getFavoritesStream(String userId) {
    return FirebaseConfig
        .collections // Changed from _firebaseConfig.collections
        .getFavorites(userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FavoriteModel.fromJson(doc.data()))
            .toList());
  }

  /// Add Pokemon to favorites
  Future<void> addToFavorites({
    required String userId,
    required PokemonModel pokemon,
    String? note,
    String? nickname,
  }) async {
    try {
      final favorite = FavoriteModel.fromPokemon(
        userId: userId,
        pokemon: pokemon,
        note: note,
        nickname: nickname,
      );

      if (!_connectivityManager.hasConnection) {
        await _offlineManager.addOperation(
          type: OfflineOperationType.addFavorite,
          data: favorite.toJson(),
        );
        return;
      }

      // Check if already exists
      final docRef =
          FirebaseConfig.collections.getFavorites(userId).doc(favorite.id);
      final doc = await docRef.get();

      if (doc.exists) {
        throw FavoriteServiceError.alreadyExists;
      }

      await docRef.set(favorite.toJson());
    } catch (e) {
      _monitoringManager.logError(
        'Failed to add favorite',
        error: e,
        additionalData: {
          'userId': userId,
          'pokemonId': pokemon.id,
        },
      );
      rethrow;
    }
  }

  /// Remove Pokemon from favorites
  Future<void> removeFromFavorites({
    required String userId,
    required String favoriteId,
  }) async {
    try {
      if (!_connectivityManager.hasConnection) {
        await _offlineManager.addOperation(
          type: OfflineOperationType.removeFavorite,
          data: {
            'userId': userId,
            'favoriteId': favoriteId,
          },
        );
        return;
      }

      await FirebaseConfig.collections
          .getFavorites(userId)
          .doc(favoriteId)
          .delete();
    } catch (e) {
      _monitoringManager.logError(
        'Failed to remove favorite',
        error: e,
        additionalData: {
          'userId': userId,
          'favoriteId': favoriteId,
        },
      );
      rethrow;
    }
  }

  /// Update favorite note/nickname
  Future<void> updateFavorite({
    required String userId,
    required String favoriteId,
    String? note,
    String? nickname,
    int? teamPosition,
  }) async {
    try {
      if (!_connectivityManager.hasConnection) {
        await _offlineManager.addOperation(
          type: OfflineOperationType.updateNote,
          data: {
            'userId': userId,
            'favoriteId': favoriteId,
            'note': note,
            'nickname': nickname,
            'teamPosition': teamPosition,
          },
        );
        return;
      }

      final docRef =
          FirebaseConfig.collections.getFavorites(userId).doc(favoriteId);

      final doc = await docRef.get();

      if (!doc.exists) {
        throw FavoriteServiceError.notFound;
      }

      final favorite = FavoriteModel.fromJson(doc.data()!);

      if (teamPosition != null) {
        await _validateTeamPosition(userId, teamPosition, favoriteId);
      }

      final updated = favorite.copyWith(
        note: note,
        nickname: nickname,
        teamPosition: teamPosition,
      );

      await docRef.update(updated.toJson());
    } catch (e) {
      _monitoringManager.logError(
        'Failed to update favorite',
        error: e,
        additionalData: {
          'userId': userId,
          'favoriteId': favoriteId,
        },
      );
      rethrow;
    }
  }

  /// Get user's team Pokemon (favorites with team positions)
  Stream<List<TeamMemberModel>> getTeamStream(String userId) {
    return FirebaseConfig.collections
        .getFavorites(userId)
        .where('teamPosition', isNull: false)
        .snapshots()
        .map((snapshot) {
      final favorites = snapshot.docs
          .map((doc) => FavoriteModel.fromJson(doc.data()))
          .where((favorite) => favorite.teamPosition != null)
          .toList();

      favorites
          .sort((a, b) => (a.teamPosition ?? 0).compareTo(b.teamPosition ?? 0));

      return favorites
          .map((favorite) => TeamMemberModel(
                position: favorite.teamPosition!,
                favorite: favorite,
                selectedMoves: const [], // Can be extended for move selection
              ))
          .toList();
    });
  }

  /// Validate team position (max 6 Pokemon, no duplicates)
  Future<void> _validateTeamPosition(
    String userId,
    int position,
    String excludeFavoriteId,
  ) async {
    if (position < 1 || position > 6) {
      throw FavoriteServiceError.maxTeamSize;
    }

    final existing = await FirebaseConfig.collections
        .getFavorites(userId)
        .where('teamPosition', isEqualTo: position)
        .where(FieldPath.documentId, isNotEqualTo: excludeFavoriteId)
        .get();

    if (existing.docs.isNotEmpty) {
      // Remove existing Pokemon from that position
      await updateFavorite(
        userId: userId,
        favoriteId: existing.docs.first.id,
        teamPosition: null,
      );
    }
  }

  /// Get favorite by ID
  Future<FavoriteModel?> getFavorite({
    required String userId,
    required String favoriteId,
  }) async {
    try {
      final doc = await FirebaseConfig.collections
          .getFavorites(userId)
          .doc(favoriteId)
          .get();

      return doc.exists ? FavoriteModel.fromJson(doc.data()!) : null;
    } catch (e) {
      _monitoringManager.logError(
        'Failed to get favorite',
        error: e,
        additionalData: {
          'userId': userId,
          'favoriteId': favoriteId,
        },
      );
      rethrow;
    }
  }
}
