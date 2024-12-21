// lib/features/favorites/services/favorite_service.dart

import 'dart:async';

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
  // Singleton implementation with proper initialization
  static final FavoriteService _instance = FavoriteService._internal();
  static final _initializationCompleter = Completer<void>();
  static bool _initializing = false;

  // Dependencies
  late final FirebaseConfig _firebaseConfig;
  late final MonitoringManager _monitoringManager;
  late final ConnectivityManager _connectivityManager;
  late final OfflineOperationManager _offlineManager;
  late final CacheManager _cacheManager;
  late final PokemonService _pokemonService;

  // Internal state
  bool _isDisposed = false;
  final _favoritesStreamController =
      StreamController<List<FavoriteModel>>.broadcast();
  final _favoriteStateController =
      StreamController<Map<String, bool>>.broadcast();
  final Map<String, bool> _favoriteStates = {};

  // Private constructor
  FavoriteService._internal();

  /// Initialize favorite service as singleton
  static Future<FavoriteService> initialize() async {
    if (!_initializing) {
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

        _initializationCompleter.complete();
        debugPrint('✅ FavoriteService initialized');
      } catch (e, stack) {
        _initializing = false;
        _initializationCompleter.completeError(e, stack);
        debugPrint('❌ FavoriteService initialization failed: $e');
        rethrow;
      }
    }

    await _initializationCompleter.future;
    return _instance;
  }

  /// Get initialization status
  static Future<void> get initialized => _initializationCompleter.future;

  /// Stream of favorite states by Pokemon ID
  Stream<Map<String, bool>> get favoriteStatesStream =>
      _favoriteStateController.stream;

  /// Stream of user's favorites
  Stream<List<FavoriteModel>> getFavoritesStream(String userId) {
    _verifyInitialized();

    return _firebaseConfig.firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        final favorites = <FavoriteModel>[];
        final states = <String, bool>{};

        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            final pokemonId = data['pokemonId'] as int;

            // Get Pokemon data
            final pokemon = await _getPokemonData(pokemonId);
            if (pokemon != null) {
              final favorite = await FavoriteModel.fromFirestore(
                data: data,
                pokemon: pokemon,
              );
              favorites.add(favorite);

              // Update favorite state
              states[favorite.id] = true;
            }
          } catch (e) {
            debugPrint('Error processing favorite: $e');
            continue;
          }
        }

        // Update states
        _favoriteStates.clear();
        _favoriteStates.addAll(states);
        _favoriteStateController.add(_favoriteStates);

        // Update favorites stream
        if (!_favoritesStreamController.isClosed) {
          _favoritesStreamController.add(favorites);
        }

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
    _verifyInitialized();

    try {
      final favorite = FavoriteModel.fromPokemon(
        userId: userId,
        pokemon: pokemon,
        note: note,
        nickname: nickname,
      );

      // Handle offline mode
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

      // Update states
      _favoriteStates[favorite.id] = true;
      _favoriteStateController.add(_favoriteStates);

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

  /// Remove from favorites
  Future<void> removeFromFavorites({
    required String userId,
    required String favoriteId,
  }) async {
    _verifyInitialized();

    try {
      // Handle offline mode
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

      // Update states
      _favoriteStates.remove(favoriteId);
      _favoriteStateController.add(_favoriteStates);

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

  /// Check if Pokemon is favorite
  bool isFavorite(String favoriteId) => _favoriteStates[favoriteId] ?? false;

  /// Get favorite by ID
  Future<FavoriteModel?> getFavorite({
    required String userId,
    required String favoriteId,
  }) async {
    _verifyInitialized();

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

  /// Verify initialization
  void _verifyInitialized() {
    if (_isDisposed) {
      throw StateError('FavoriteService has been disposed');
    }
    if (!_initializationCompleter.isCompleted) {
      throw StateError('FavoriteService not initialized');
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    await _favoritesStreamController.close();
    await _favoriteStateController.close();
    _isDisposed = true;
  }
}
