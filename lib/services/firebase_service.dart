// lib/services/firebase_service.dart

/// Firebase service to handle all Firebase operations.
/// Manages authentication and Firestore operations with proper error handling.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/firebase_config.dart';
import '../core/utils/monitoring_manager.dart';
import '../core/utils/connectivity_manager.dart';
import '../features/auth/models/user_model.dart';
import '../features/favorites/models/favorite_model.dart';
import '../features/pokemon/models/pokemon_model.dart';

/// Firebase service errors
class FirebaseServiceError implements Exception {
  /// Error message
  final String message;

  /// Error code if available
  final String? code;

  /// Original error
  final dynamic originalError;

  /// Constructor
  const FirebaseServiceError({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'FirebaseServiceError: $message';
}

/// Firebase service class
class FirebaseService {
  // Singleton implementation
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Core dependencies
  late final FirebaseConfig _config;
  late final MonitoringManager _monitoring;
  late final ConnectivityManager _connectivity;

  // Firebase instances
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;

  // Stream controllers
  final _userController = StreamController<UserModel?>.broadcast();
  final _favoritesController =
      StreamController<List<FavoriteModel>>.broadcast();

  // Internal state
  bool _isInitialized = false;
  Timer? _cleanupTimer;

  /// Stream of authenticated user
  Stream<UserModel?> get userStream => _userController.stream;

  /// Current authenticated user
  UserModel? get currentUser {
    final user = _auth.currentUser;
    return user != null ? UserModel.fromFirebaseUser(user) : null;
  }

  /// Initialize service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize dependencies
      _config = FirebaseConfig();
      _monitoring = MonitoringManager();
      _connectivity = ConnectivityManager();

      await _config.initialize();

      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;

      // Setup auth state listener
      _auth.authStateChanges().listen(_handleAuthStateChange);

      // Setup cleanup timer
      _setupCleanupTimer();

      _isInitialized = true;

      if (kDebugMode) {
        print('✅ Firebase service initialized');
      }
    } catch (e) {
      _monitoring.logError('Firebase service initialization failed', error: e);
      rethrow;
    }
  }

  /// Authentication Methods

  /// Sign in with email and password
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw const FirebaseServiceError(
          message: 'Sign in failed: No user returned',
        );
      }

      final user = UserModel.fromFirebaseUser(userCredential.user!);
      await _updateUserData(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw FirebaseServiceError(
        message: 'Sign in failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Register with email and password
  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw const FirebaseServiceError(
          message: 'Registration failed: No user returned',
        );
      }

      final user = UserModel.fromFirebaseUser(userCredential.user!);
      await _createUserDocument(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw FirebaseServiceError(
        message: 'Registration failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw FirebaseServiceError(
        message: 'Sign out failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw FirebaseServiceError(
        message: 'Password reset failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Update user profile
  Future<UserModel> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const FirebaseServiceError(message: 'No authenticated user');
      }

      await user.updateDisplayName(displayName);
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      final updatedUser = UserModel.fromFirebaseUser(user);
      await _updateUserData(updatedUser);
      return updatedUser;
    } catch (e) {
      throw FirebaseServiceError(
        message: 'Profile update failed: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Favorites Methods

  /// Get user's favorites stream
  Stream<List<FavoriteModel>> getFavoritesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .asyncMap((snapshot) async {
      final favorites = <FavoriteModel>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final pokemonId = data['pokemonId'] as int;

          // Get Pokemon data
          final pokemonDoc = await _firestore
              .collection('pokemon')
              .doc(pokemonId.toString())
              .get();

          if (pokemonDoc.exists) {
            final pokemon = PokemonModel.fromJson(
              pokemonDoc.data()!,
            );

            favorites.add(await FavoriteModel.fromFirestore(
              data: data,
              pokemon: pokemon,
            ));
          }
        } catch (e) {
          _monitoring.logError(
            'Error processing favorite',
            error: e,
            additionalData: {'docId': doc.id},
          );
        }
      }

      return favorites;
    });
  }

  /// Add to favorites
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

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(favorite.id)
          .set(favorite.toFirestore());
    } catch (e) {
      throw FirebaseServiceError(
        message: 'Failed to add favorite: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Remove from favorites
  Future<void> removeFromFavorites({
    required String userId,
    required String favoriteId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(favoriteId)
          .delete();
    } catch (e) {
      throw FirebaseServiceError(
        message: 'Failed to remove favorite: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Settings Methods

  /// Get user settings
  Future<Map<String, dynamic>> getUserSettings(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('preferences')
          .get();

      return doc.data() ?? _getDefaultSettings();
    } catch (e) {
      throw FirebaseServiceError(
        message: 'Failed to get settings: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Update user settings
  Future<void> updateUserSettings({
    required String userId,
    required Map<String, dynamic> settings,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('preferences')
          .set(settings, SetOptions(merge: true));
    } catch (e) {
      throw FirebaseServiceError(
        message: 'Failed to update settings: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Private Helper Methods

  /// Handle auth state changes
  void _handleAuthStateChange(User? user) {
    if (!_userController.isClosed) {
      _userController.add(
        user != null ? UserModel.fromFirebaseUser(user) : null,
      );
    }
  }

  /// Create new user document
  Future<void> _createUserDocument(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).set({
        'email': user.email,
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _monitoring.logError(
        'Failed to create user document',
        error: e,
        additionalData: {'userId': user.id},
      );
    }
  }

  /// Update user document
  Future<void> _updateUserData(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update({
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _monitoring.logError(
        'Failed to update user document',
        error: e,
        additionalData: {'userId': user.id},
      );
    }
  }

  /// Handle auth errors
  FirebaseServiceError _handleAuthError(FirebaseAuthException e) {
    String message;

    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
        message = 'Invalid email or password';
        break;
      case 'email-already-in-use':
        message = 'Email already registered';
        break;
      case 'weak-password':
        message = 'Password is too weak';
        break;
      case 'invalid-email':
        message = 'Invalid email address';
        break;
      case 'operation-not-allowed':
        message = 'Operation not allowed';
        break;
      case 'user-disabled':
        message = 'User account has been disabled';
        break;
      default:
        message = e.message ?? 'An unknown error occurred';
    }

    return FirebaseServiceError(
      message: message,
      code: e.code,
      originalError: e,
    );
  }

  /// Get default settings
  Map<String, dynamic> _getDefaultSettings() {
    return {
      'theme': 'light',
      'language': 'en',
      'notifications': {
        'enabled': true,
        'pushEnabled': true,
        'emailEnabled': true,
      },
    };
  }

  /// Setup cleanup timer
  void _setupCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _cleanupResources(),
    );
  }

  /// Cleanup resources
  void _cleanupResources() {
    // Cleanup can be implemented if needed
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _userController.close();
    _favoritesController.close();

    if (kDebugMode) {
      print('🧹 Firebase service disposed');
    }
  }
}
