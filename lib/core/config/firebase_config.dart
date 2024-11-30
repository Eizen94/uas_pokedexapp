// lib/core/config/firebase_config.dart

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  // Private constructor and instance
  FirebaseConfig._();
  static final FirebaseConfig _instance = FirebaseConfig._();

  // Getter for instance
  static FirebaseConfig get instance => _instance;

  // State management
  bool _initialized = false;
  bool _initializing = false;
  Completer<void>? _initCompleter;

  // Service status controllers
  final _authStatusController = StreamController<bool>.broadcast();
  final _firestoreStatusController = StreamController<bool>.broadcast();

  // Getters
  bool get isInitialized => _initialized;
  bool get isInitializing => _initializing;
  Stream<bool> get authStatus => _authStatusController.stream;
  Stream<bool> get firestoreStatus => _firestoreStatusController.stream;

  // Initialize Firebase with retry mechanism
  Future<void> initializeApp({int maxRetries = 3}) async {
    // If already initialized, return immediately
    if (_initialized) {
      if (kDebugMode) {
        print('🔥 Firebase already initialized');
      }
      return;
    }

    // If initialization is in progress, wait for it
    if (_initializing) {
      if (kDebugMode) {
        print('⏳ Firebase initialization in progress, waiting...');
      }
      return _initCompleter?.future;
    }

    // Start initialization
    _initializing = true;
    _initCompleter = Completer<void>();

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
          _initCompleter?.complete();
          return;
        }

        // Initialize Firebase with configuration
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyA788aYkne3gRiwAtZLtsVMRl5reUPMcXg',
            appId: '1:631128211674:android:f88221525f9e09b7f465e3',
            messagingSenderId: '631128211674',
            projectId: 'uas-pokedexapp',
            storageBucket: 'uas-pokedexapp.appspot.com',
          ),
        );

        // Initialize services
        await _initializeServices();

        _initialized = true;
        _initCompleter?.complete();

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
          final error = FirebaseException(
            plugin: 'core',
            message:
                'Failed to initialize Firebase after $maxRetries attempts: $e',
          );
          _initCompleter?.completeError(error);
          throw error;
        }

        // Wait before retrying with exponential backoff
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
  }

  // Initialize Firebase services
  Future<void> _initializeServices() async {
    try {
      // Initialize Auth
      final auth = FirebaseAuth.instance;
      _authStatusController.add(true);

      if (kDebugMode) {
        print('✅ Firebase Auth initialized');
      }

      // Initialize Firestore with offline persistence
      final firestore = FirebaseFirestore.instance;
      await firestore
          .enablePersistence(const PersistenceSettings(synchronizeTabs: true));
      await firestore.collection('test').doc('test').get();
      _firestoreStatusController.add(true);

      if (kDebugMode) {
        print('✅ Firestore initialized with persistence');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Service initialization warning: $e');
      }
      // Don't throw here - services can be initialized later if needed
    }
  }

  // Reset Firebase configuration
  Future<void> reset() async {
    if (kDebugMode) {
      print('🔄 Resetting Firebase configuration...');
    }

    try {
      _initialized = false;
      _initializing = false;
      _initCompleter = null;

      // Reset service status
      _authStatusController.add(false);
      _firestoreStatusController.add(false);

      // Delete all apps
      final apps = Firebase.apps;
      await Future.wait(
        apps.map((app) => app.delete()),
      );

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

  // Cleanup resources
  Future<void> dispose() async {
    await Future.wait([
      _authStatusController.close(),
      _firestoreStatusController.close(),
    ]);
    _initialized = false;
    _initializing = false;
    _initCompleter = null;
  }

  // Get initialization status
  Future<void> get initializationComplete =>
      _initCompleter?.future ?? Future.value();
}
