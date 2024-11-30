// lib/core/config/firebase_config.dart

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  // Private constructor
  FirebaseConfig._();

  // Singleton instance
  static final FirebaseConfig instance = FirebaseConfig._();

  // State tracking
  static bool _initialized = false;
  static bool _initializing = false;
  static final _initCompleter = Completer<void>();

  // Stream controllers for service status
  final _authStatusController = StreamController<bool>.broadcast();
  final _firestoreStatusController = StreamController<bool>.broadcast();

  // Getters for status streams
  Stream<bool> get authStatus => _authStatusController.stream;
  Stream<bool> get firestoreStatus => _firestoreStatusController.stream;

  // Initialize Firebase with retry mechanism
  Future<void> initializeApp({int maxRetries = 3}) async {
    if (_initialized) {
      if (kDebugMode) {
        print('🔥 Firebase already initialized');
      }
      return;
    }

    if (_initializing) {
      if (kDebugMode) {
        print('⏳ Firebase initialization in progress, waiting...');
      }
      return _initCompleter.future;
    }

    _initializing = true;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        if (kDebugMode) {
          print('🚀 Initializing Firebase (Attempt ${retryCount + 1})...');
        }

        // Check for existing Firebase apps
        if (Firebase.apps.isNotEmpty) {
          if (kDebugMode) {
            print('♻️ Using existing Firebase app');
          }
          _initialized = true;
          _initCompleter.complete();
          return;
        }

        // Initialize Firebase
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyA788aYkne3gRiwAtZLtsVMRl5reUPMcXg',
            appId: '1:631128211674:android:f88221525f9e09b7f465e3',
            messagingSenderId: '631128211674',
            projectId: 'uas-pokedexapp',
            storageBucket: 'uas-pokedexapp.appspot.com',
          ),
        );

        // Initialize and verify services
        await _initializeServices();

        _initialized = true;
        _initCompleter.complete();

        if (kDebugMode) {
          print('✅ Firebase initialized successfully');
        }

        return;
      } catch (e) {
        retryCount++;
        if (kDebugMode) {
          print('❌ Firebase initialization error (Attempt $retryCount): $e');
        }

        if (retryCount == maxRetries) {
          _initCompleter.completeError(e);
          throw FirebaseException(
            plugin: 'core',
            message:
                'Failed to initialize Firebase after $maxRetries attempts: $e',
          );
        }

        // Wait before retrying
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
  }

  // Initialize individual Firebase services
  Future<void> _initializeServices() async {
    try {
      // Initialize Auth
      final auth = FirebaseAuth.instance;
      _authStatusController.add(true);

      if (kDebugMode) {
        print('✅ Firebase Auth initialized');
      }

      // Initialize Firestore
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('test').doc('test').get();
      _firestoreStatusController.add(true);

      if (kDebugMode) {
        print('✅ Firestore initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Service initialization warning: $e');
      }
      // Don't throw here - services can be initialized later if needed
    }
  }

  // Reset Firebase instance (useful for testing and error recovery)
  Future<void> reset() async {
    if (kDebugMode) {
      print('🔄 Resetting Firebase configuration...');
    }

    _initialized = false;
    _initializing = false;

    // Create new completer if the old one was completed
    if (_initCompleter.isCompleted) {
      _initCompleter = Completer<void>();
    }

    // Reset service status
    _authStatusController.add(false);
    _firestoreStatusController.add(false);

    try {
      final apps = Firebase.apps;
      for (final app in apps) {
        await app.delete();
      }

      if (kDebugMode) {
        print('✅ Firebase reset successful');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during Firebase reset: $e');
      }
      rethrow;
    }
  }

  // Clean up resources
  Future<void> dispose() async {
    await _authStatusController.close();
    await _firestoreStatusController.close();
  }

  // Utility methods
  bool get isInitialized => _initialized;
  bool get isInitializing => _initializing;
  Future<void> get initializationComplete => _initCompleter.future;
}
