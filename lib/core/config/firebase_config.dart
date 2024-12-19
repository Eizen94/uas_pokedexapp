// lib/core/config/firebase_config.dart

/// Firebase configuration and initialization manager.
/// Handles Firebase setup and provides access to Firebase services.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration manager
class FirebaseConfig {
  static final FirebaseConfig _instance = FirebaseConfig._internal();
  factory FirebaseConfig() => _instance;
  FirebaseConfig._internal();

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  bool _isInitialized = false;
  final Completer<void> _initCompleter = Completer<void>();

  Future<void> get initialized => _initCompleter.future;

  Future<void> initialize() async {
    if (_isInitialized) {
      return await initialized;
    }

    try {
      await Firebase.initializeApp(
        options: _getFirebaseOptions(),
      );

      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;

      await _configureFirestore();
      _isInitialized = true;
      _initCompleter.complete();

      debugPrint('Firebase initialized successfully');
    } catch (e) {
      _initCompleter.completeError(e);
      debugPrint('Failed to initialize Firebase: $e');
      rethrow;
    }
  }

  FirebaseAuth get auth {
    assert(_isInitialized,
        'FirebaseConfig must be initialized before accessing auth');
    return _auth!;
  }

  FirebaseFirestore get firestore {
    assert(_isInitialized,
        'FirebaseConfig must be initialized before accessing firestore');
    return _firestore!;
  }

  FirebaseOptions _getFirebaseOptions() {
    return const FirebaseOptions(
        apiKey: "AIzaSyA788aYkne3gRiwAtZLtsVMRl5reUPMcXg",
        appId: "1:631128211674:android:f88221525f9e09b7f465e3",
        messagingSenderId: "631128211674",
        projectId: "uas-pokedexapp",
        storageBucket: "uas-pokedexapp.firebasestorage.app");
  }

  /// Get Firebase options based on platform
  FirebaseOptions _getFirebaseOptions() {
    return const FirebaseOptions(
        apiKey: "AIzaSyA788aYkne3gRiwAtZLtsVMRl5reUPMcXg",
        appId: "1:631128211674:android:f88221525f9e09b7f465e3",
        messagingSenderId: "631128211674",
        projectId: "uas-pokedexapp",
        storageBucket: "uas-pokedexapp.firebasestorage.app");
  }

  /// Configure Firestore settings
  Future<void> _configureFirestore() async {
    // Configure Firestore for offline persistence within free tier limits
    _firestore.settings.persistenceEnabled;
    _firestore.settings.cacheSizeBytes;

    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  /// Get Firebase Auth instance
  FirebaseAuth get auth => _auth;

  /// Get Firestore instance
  FirebaseFirestore get firestore => _firestore;

  /// Collection references
  static final collections = _FirebaseCollections();

  /// Firebase error handler
  static String handleError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You don\'t have permission to perform this action';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again later';
      case 'cancelled':
        return 'Operation cancelled';
      case 'unknown':
        return 'An unknown error occurred';
      case 'invalid-argument':
        return 'Invalid data provided';
      case 'deadline-exceeded':
        return 'Operation timed out';
      case 'not-found':
        return 'Requested resource not found';
      case 'already-exists':
        return 'Resource already exists';
      case 'resource-exhausted':
        return 'Quota exceeded';
      case 'failed-precondition':
        return 'Operation failed due to invalid system state';
      case 'aborted':
        return 'Operation aborted';
      case 'out-of-range':
        return 'Operation specified invalid range';
      case 'unimplemented':
        return 'Operation not implemented';
      case 'internal':
        return 'Internal system error';
      case 'data-loss':
        return 'Unrecoverable data loss/corruption';
      case 'unauthenticated':
        return 'Authentication required';
      default:
        return error.message ?? 'An error occurred';
    }
  }
}

/// Firebase collection references
class _FirebaseCollections {
  /// Users collection reference
  CollectionReference<Map<String, dynamic>> get users =>
      FirebaseFirestore.instance.collection('users');

  /// Favorites collection reference
  CollectionReference<Map<String, dynamic>> getFavorites(String userId) =>
      users.doc(userId).collection('favorites');

  /// Notes collection reference
  CollectionReference<Map<String, dynamic>> getNotes(String userId) =>
      users.doc(userId).collection('notes');

  /// Settings collection reference
  CollectionReference<Map<String, dynamic>> getSettings(String userId) =>
      users.doc(userId).collection('settings');
}
