// lib/features/favorites/services/favorite_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/firebase_config.dart';
import '../../../core/utils/monitoring_manager.dart';
import '../../../core/utils/connectivity_manager.dart';
import '../../../core/utils/offline_operation.dart';
import '../../../core/utils/cache_manager.dart';
import '../../pokemon/services/pokemon_service.dart';
import '../../pokemon/models/pokemon_model.dart';
import '../models/favorite_model.dart';

/// Favorite service error messages
class FavoriteServiceError implements Exception {
  final String message;
  final dynamic originalError;

  const FavoriteServiceError({
    required this.message,
    this.originalError,
  });

  @override
  String toString() => message;

  static const String notFound = 'Favorite not found';
  static const String alreadyExists = 'Pokemon already in favorites';
  static const String saveFailed = 'Failed to save favorite';
  static const String deleteFailed = 'Failed to delete favorite';
  static const String networkError = 'Network error occurred';
  static const String maxTeamSize = 'Maximum team size reached (6 Pokemon)';
}

/// Service class for managing favorites
class FavoriteService {
  static final FavoriteService _instance = FavoriteService._internal();
  static bool _initializing = false;
  static bool _initialized = false;

  // Dependencies
  late final FirebaseConfig _firebaseConfig;
  late final MonitoringManager _monitoringManager;
  late final ConnectivityManager _connectivityManager;
  late final OfflineOperationManager _offlineManager;
  late final CacheManager _cacheManager;
  late final PokemonService _pokemonService;

  // Internal state
  bool _isDisposed = false;
  final _favoritesController =
      StreamController<List<FavoriteModel>>.broadcast();

  /// Private constructor
  FavoriteService._internal();

  /// Initialize service as singleton
  static Future<FavoriteService> initialize() async {
    if (_initialized && !_instance._isDisposed) {
      return _instance;
    }

    if (_initializing) {
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_initialized) return _instance;
    }

    _initializing = true;

    try {
      debugPrint('🎯 FavoriteService: Starting initialization...');

      // Initialize dependencies
      _instance._firebaseConfig = FirebaseConfig();
      await _instance._firebaseConfig.initialize();

      _instance._monitoringManager = MonitoringManager();
      _instance._connectivityManager = ConnectivityManager();
      _instance._cacheManager = await CacheManager.initialize();
      _instance._offlineManager = await OfflineOperationManager.initialize();
      _instance._pokemonService = await PokemonService.initialize();

      _initialized = true;
      _initializing = false;

      debugPrint('✅ FavoriteService initialized');
      return _instance;
    } catch (e, stack) {
      _initializing = false;
      debugPrint('❌ FavoriteService initialization failed: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  /// Stream of user's favorites
  Stream<List<FavoriteModel>> getFavoritesStream(String userId) {
    _verifyState();

    return _firebaseConfig.firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        final favorites = <FavoriteModel>[];

        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            final pokemonId = data['pokemonId'] as int;

            // Get Pokemon data
            final pokemon = await _getPokemonData(pokemonId);
            if (pokemon != null) {
              favorites.add(await FavoriteModel.fromFirestore(
                data: data,
                pokemon: pokemon,
              ));
            }
          } catch (e) {
            debugPrint('Error processing favorite: $e');
            continue;
          }
        }

        _favoritesController.add(favorites);
        return favorites;
      } catch (e, stack) {
        _monitoringManager.logError(
          'Error fetching favorites',
          error: e,
          stackTrace: stack,
        );
        return [];
      }
    });
  }

  /// Add Pokemon to favorites
  Future<void> addToFavorites({
    required String userId,
    required PokemonModel pokemon,
    String? note,
    String? nickname,
  }) async {
    _verifyState();

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
          data: favorite.toFirestore(),
        );
        return;
      }

      // Check if already exists
      final docRef = _firebaseConfig.firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(favorite.id);

      final doc = await docRef.get();
      if (doc.exists) {
        throw const FavoriteServiceError(
          message: FavoriteServiceError.alreadyExists,
        );
      }

      await docRef.set(favorite.toFirestore());

      // Cache favorite
      await _cacheManager.put(
        'favorite_${favorite.id}',
        favorite.toJson(),
      );
    } catch (e, stack) {
      _monitoringManager.logError(
        'Failed to add favorite',
        error: e,
        stackTrace: stack,
        additionalData: {
          'userId': userId,
          'pokemonId': pokemon.id,
        },
      );
      throw FavoriteServiceError(
        message: FavoriteServiceError.saveFailed,
        originalError: e,
      );
    }
  }

  /// Remove Pokemon from favorites
  Future<void> removeFromFavorites({
    required String userId,
    required String favoriteId,
  }) async {
    _verifyState();

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

      await _firebaseConfig.firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(favoriteId)
          .delete();

      // Remove from cache
      await _cacheManager.remove('favorite_$favoriteId');
    } catch (e, stack) {
      _monitoringManager.logError(
        'Failed to remove favorite',
        error: e,
        stackTrace: stack,
        additionalData: {
          'userId': userId,
          'favoriteId': favoriteId,
        },
      );
      throw FavoriteServiceError(
        message: FavoriteServiceError.deleteFailed,
        originalError: e,
      );
    }
  }

  /// Update favorite details
  Future<void> updateFavorite({
    required String userId,
    required String favoriteId,
    String? note,
    String? nickname,
    int? teamPosition,
  }) async {
    _verifyState();

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

      final docRef = _firebaseConfig.firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(favoriteId);

      final doc = await docRef.get();
      if (!doc.exists) {
        throw const FavoriteServiceError(
          message: FavoriteServiceError.notFound,
        );
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

      await docRef.update(updated.toFirestore());

      // Update cache
      await _cacheManager.put(
        'favorite_$favoriteId',
        updated.toJson(),
      );
    } catch (e, stack) {
      _monitoringManager.logError(
        'Failed to update favorite',
        error: e,
        stackTrace: stack,
        additionalData: {
          'userId': userId,
          'favoriteId': favoriteId,
        },
      );
      throw FavoriteServiceError(
        message: FavoriteServiceError.saveFailed,
        originalError: e,
      );
    }
  }

  /// Get Pokemon data with caching
  Future<PokemonModel?> _getPokemonData(int pokemonId) async {
    try {
      final cacheKey = 'pokemon_$pokemonId';

      // Try cache first
      final cached = await _cacheManager.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return PokemonModel.fromJson(cached);
      }

      // Fetch from API
      final detail = await _pokemonService.getPokemonDetail(pokemonId);

      // Cache result
      await _cacheManager.put(cacheKey, detail.toJson());

      return detail;
    } catch (e) {
      debugPrint('Error getting Pokemon data: $e');
      return null;
    }
  }

  /// Validate team position
  Future<void> _validateTeamPosition(
    String userId,
    int position,
    String excludeFavoriteId,
  ) async {
    if (position < 1 || position > 6) {
      throw const FavoriteServiceError(
        message: FavoriteServiceError.maxTeamSize,
      );
    }

    final existing = await _firebaseConfig.firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .where('teamPosition', isEqualTo: position)
        .where(FieldPath.documentId, isNotEqualTo: excludeFavoriteId)
        .get();

    if (existing.docs.isNotEmpty) {
      // Remove position from existing Pokemon
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
    _verifyState();

    try {
      // Try cache first
      final cached =
          await _cacheManager.get<Map<String, dynamic>>('favorite_$favoriteId');
      if (cached != null) {
        return FavoriteModel.fromJson(cached);
      }

      final doc = await _firebaseConfig.firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(favoriteId)
          .get();

      if (!doc.exists) return null;

      final favorite = FavoriteModel.fromJson(doc.data()!);

      // Cache result
      await _cacheManager.put(
        'favorite_$favoriteId',
        favorite.toJson(),
      );

      return favorite;
    } catch (e, stack) {
      _monitoringManager.logError(
        'Failed to get favorite',
        error: e,
        stackTrace: stack,
        additionalData: {
          'userId': userId,
          'favoriteId': favoriteId,
        },
      );
      return null;
    }
  }

  /// Verify service state
  void _verifyState() {
    if (_isDisposed) {
      throw StateError('FavoriteService has been disposed');
    }
    if (!_initialized) {
      throw StateError('FavoriteService not initialized');
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    await _favoritesController.close();
    _isDisposed = true;
  }

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Check if service is disposed
  bool get isDisposed => _isDisposed;
}
