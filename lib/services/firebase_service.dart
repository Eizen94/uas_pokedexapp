// lib/services/firebase_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/auth/models/user_model.dart';
import '../features/favorites/models/favorite_model.dart';
import '../core/utils/connectivity_manager.dart';

class FirebaseService {
  // Singleton instance
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectivityManager _connectivity = ConnectivityManager();

  // Collection references
  late final CollectionReference _usersRef;
  late final CollectionReference _favoritesRef;
  late final CollectionReference _settingsRef;

  // Cache management
  final Map<String, dynamic> _cache = {};
  Timer? _cacheCleanupTimer;
  static const cacheDuration = Duration(hours: 1);

  // Initialize service
  Future<void> initialize() async {
    try {
      // Initialize collection references
      _usersRef = _firestore.collection('users');
      _favoritesRef = _firestore.collection('favorites');
      _settingsRef = _firestore.collection('settings');

      // Configure Firestore settings
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Setup cache cleanup
      _setupCacheCleanup();

      // Initialize connectivity manager
      await _connectivity.initialize();

      if (kDebugMode) {
        print('✅ Firebase service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase service initialization error: $e');
      }
      rethrow;
    }
  }

  // User Management Methods

  // Get current user data
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _usersRef.doc(user.uid).get();
      if (!doc.exists) return null;

      return UserModel.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting current user: $e');
      }
      return null;
    }
  }

  // Update user data
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _usersRef.doc(uid).update({
        ...data,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update cache
      _cache[uid] = data;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating user data: $e');
      }
      rethrow;
    }
  }

  // Favorites Management

  // Add to favorites
  Future<void> addToFavorites(String userId, FavoriteModel favorite) async {
    try {
      final docRef = _favoritesRef.doc(favorite.id);

      await docRef.set(
        favorite.toMap()
          ..addAll({
            'addedAt': FieldValue.serverTimestamp(),
            'userId': userId,
          }),
      );

      // Update local cache
      _cache['favorites_$userId'] = _cache['favorites_$userId'] ?? [];
      (_cache['favorites_$userId'] as List).add(favorite);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding to favorites: $e');
      }
      rethrow;
    }
  }

  // Remove from favorites
  Future<void> removeFromFavorites(String userId, String favoriteId) async {
    try {
      await _favoritesRef.doc(favoriteId).delete();

      // Update local cache
      if (_cache.containsKey('favorites_$userId')) {
        final favorites = _cache['favorites_$userId'] as List;
        favorites.removeWhere((favorite) => favorite.id == favoriteId);
        _cache['favorites_$userId'] = favorites;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removing from favorites: $e');
      }
      rethrow;
    }
  }

  // Get user favorites
  Stream<List<FavoriteModel>> getUserFavorites(String userId) {
    try {
      return _favoritesRef
          .where('userId', isEqualTo: userId)
          .orderBy('addedAt', descending: true)
          .snapshots()
          .map((snapshot) {
        final favorites = snapshot.docs
            .map((doc) => FavoriteModel.fromFirestore(doc))
            .toList();

        // Update cache
        _cache['favorites_$userId'] = favorites;

        return favorites;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user favorites: $e');
      }
      rethrow;
    }
  }

  // Settings Management

  // Get user settings
  Future<Map<String, dynamic>> getUserSettings(String userId) async {
    try {
      final doc = await _settingsRef.doc(userId).get();
      if (!doc.exists) {
        return _getDefaultSettings();
      }
      return (doc.data() as Map<String, dynamic>)['settings'] ??
          _getDefaultSettings();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user settings: $e');
      }
      return _getDefaultSettings();
    }
  }

  // Update user settings
  Future<void> updateUserSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    try {
      await _settingsRef.doc(userId).set({
        'settings': settings,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update cache
      _cache['settings_$userId'] = settings;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating user settings: $e');
      }
      rethrow;
    }
  }

  // Cache Management

  void _setupCacheCleanup() {
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _cleanCache(),
    );
  }

  void _cleanCache() {
    _cache.clear();
    if (kDebugMode) {
      print('🧹 Cache cleaned');
    }
  }

  // Default Settings
  Map<String, dynamic> _getDefaultSettings() {
    return {
      'theme': 'light',
      'language': 'en',
      'notifications': true,
      'autoSync': true,
    };
  }

  // Offline Support

  // Check if operation can proceed
  Future<bool> _canPerformOperation() async {
    if (await _connectivity.checkConnectivity()) {
      return true;
    }

    // If offline, check if operation can be performed offline
    return _auth.currentUser != null;
  }

  // Batch Operations

  // Perform batch write
  Future<void> performBatchWrite(
    Future<void> Function(WriteBatch batch) operations,
  ) async {
    final batch = _firestore.batch();

    try {
      await operations(batch);
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error performing batch write: $e');
      }
      rethrow;
    }
  }

  // Transaction Operations

  // Perform transaction
  Future<T> performTransaction<T>(
    Future<T> Function(Transaction transaction) operations,
  ) async {
    try {
      return await _firestore.runTransaction(operations);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error performing transaction: $e');
      }
      rethrow;
    }
  }

  // Resource Cleanup
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _cleanCache();
  }

  // Stream Transformers

  // Transform snapshot to model
  Stream<T> transformSnapshot<T>(
    Stream<DocumentSnapshot> snapshot,
    T Function(DocumentSnapshot) transform,
  ) {
    return snapshot.map(transform);
  }

  // Error Handling

  // Handle Firebase exceptions
  Exception handleFirebaseException(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return Exception('You do not have permission to perform this action');
        case 'not-found':
          return Exception('The requested resource was not found');
        case 'already-exists':
          return Exception('The resource already exists');
        case 'resource-exhausted':
          return Exception('Too many requests. Please try again later');
        default:
          return Exception(error.message ?? 'An unknown error occurred');
      }
    }
    return Exception('An unexpected error occurred: $error');
  }
}
