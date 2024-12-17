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

  /// Singleton instance
  factory FirebaseConfig() => _instance;

  FirebaseConfig._internal();

  /// Firebase application instance
  late final FirebaseApp _app;

  /// Firebase Auth instance
  late final FirebaseAuth _auth;

  /// Firestore instance
  late final FirebaseFirestore _firestore;

  /// Initialize Firebase
  Future<void> initialize() async {
    try {
      _app = await Firebase.initializeApp(
        options: _getFirebaseOptions(),
      );

      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;

      await _configureFirestore();

      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Firebase: $e');
      rethrow;
    }
  }

  /// Get Firebase options based on platform
  FirebaseOptions _getFirebaseOptions() {
    // Using const constructor for options to ensure values are compile-time constants
    return const FirebaseOptions(
      apiKey: 'YOUR_API_KEY',
      appId: 'YOUR_APP_ID',
      messagingSenderId: 'YOUR_SENDER_ID',
      projectId: 'YOUR_PROJECT_ID',
      // Free tier doesn't require storage bucket
      storageBucket: null,
    );
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
