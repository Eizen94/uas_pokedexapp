// lib/core/config/firebase_config.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static bool _initialized = false;

  static Future<void> initializeFirebase() async {
    if (_initialized) {
      if (kDebugMode) {
        print('📱 Firebase already initialized, skipping...');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('📱 Starting Firebase initialization...');
      }

      if (!Firebase.apps.isNotEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyA788aYkne3gRiwAtZLtsVMRl5reUPMcXg',
            appId: '1:631128211674:android:f88221525f9e09b7f465e3',
            messagingSenderId: '631128211674',
            projectId: 'uas-pokedexapp',
            storageBucket: 'uas-pokedexapp.appspot.com',
          ),
        );

        _initialized = true;

        if (kDebugMode) {
          print('🔥 Firebase Core initialized successfully');
        }

        // Initialize Firebase Auth
        try {
          final auth = FirebaseAuth.instance;
          if (kDebugMode) {
            print('📱 Firebase Auth initialized: ${auth.app.name}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Firebase Auth Error: $e');
          }
          rethrow;
        }

        // Initialize Firestore
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('test').doc('test').get();
          if (kDebugMode) {
            print('💾 Firestore initialized and connected');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Firestore Error: $e');
          }
          // Don't rethrow Firestore errors as they're non-critical
        }
      } else {
        if (kDebugMode) {
          print('🔄 Firebase app already exists, using existing instance');
        }
        _initialized = true;
      }
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        print('❌ Firebase Error: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Firebase: $e');
      }
      rethrow;
    }
  }

  // Singleton instance checking
  static bool get isInitialized => _initialized;

  // Helper method to get Firebase instance
  static FirebaseApp? get app =>
      Firebase.apps.isNotEmpty ? Firebase.app() : null;

  // Helper method to check if Auth is ready
  static bool get isAuthReady =>
      isInitialized && FirebaseAuth.instance.app != null;

  // Helper method to check if Firestore is ready
  static bool get isFirestoreReady =>
      isInitialized && FirebaseFirestore.instance.app != null;

  // Reset initialization state (useful for testing)
  static void reset() {
    _initialized = false;
  }
}
