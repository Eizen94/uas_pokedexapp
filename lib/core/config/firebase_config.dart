// lib/core/config/firebase_config.dart

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  // Private constructor and singleton instance
  FirebaseConfig._();
  static final FirebaseConfig _instance = FirebaseConfig._();

  // State management
  bool _initialized = false;
  bool _initializing = false;
  final _initCompleter = Completer<void>();

  // Service status controllers
  final _authStatusController = StreamController<bool>.broadcast();
  final _firestoreStatusController = StreamController<bool>.broadcast();

  // Getters
  static FirebaseConfig get instance => _instance;
  bool get isInitialized => _initialized;
  bool get isInitializing => _initializing;
  Stream<bool> get authStatus => _authStatusController.stream;
  Stream<bool> get firestoreStatus => _firestoreStatusController.stream;

  // Initialize Firebase with retry mechanism and proper cleanup
  Future<void> initializeApp({int maxRetries = 3}) async {
    if (_initialized) {
      if (kDebugMode) {
        print('🔥 Firebase already initialized');
      }
      return;
    }

    // Handle initialization in progress
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

        // Check existing Firebase apps
        if (Firebase.apps.isNotEmpty) {
          _initialized = true;
          _initCompleter.complete();
          if (kDebugMode) {
            print('♻️ Using existing Firebase app');
          }
          return;
        }

        // Initialize Firebase with optimized settings
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyA788aYkne3gRiwAtZLtsVMRl5reUPMcXg',
            appId: '1:631128211674:android:f88221525f9e09b7f465e3',
            messagingSenderId: '631128211674',
            projectId: 'uas-pokedexapp',
            storageBucket: 'uas-pokedexapp.appspot.com',
          ),
        );

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
          final error = FirebaseException(
            plugin: 'core',
            message:
                'Failed to initialize Firebase after $maxRetries attempts: $e',
          );
          _initCompleter.completeError(error);
          throw error;
        }

        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
  }

  // Initialize Firebase services with optimized settings
  Future<void> _initializeServices() async {
    try {
      // Initialize Auth with persistence
      final auth = FirebaseAuth.instance;
      await auth.setPersistence(Persistence.LOCAL);
      _authStatusController.add(true);

      if (kDebugMode) {
        print('✅ Firebase Auth initialized with local persistence');
      }

      // Initialize Firestore with optimized settings
      final firestore = FirebaseFirestore.instance;
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        sslEnabled: true,
      );

      // Test connection
      await firestore.collection('test').doc('test').get();
      _firestoreStatusController.add(true);

      if (kDebugMode) {
        print('✅ Firestore initialized with optimized persistence');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Service initialization warning: $e');
      }
    }
  }

  // Reset Firebase configuration with proper cleanup
  Future<void> reset() async {
    if (kDebugMode) {
      print('🔄 Resetting Firebase configuration...');
    }

    try {
      _initialized = false;
      _initializing = false;

      // Reset service status
      _authStatusController.add(false);
      _firestoreStatusController.add(false);

      // Sign out user
      await FirebaseAuth.instance.signOut();

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

  // Clean resource disposal
  Future<void> dispose() async {
    await Future.wait([
      _authStatusController.close(),
      _firestoreStatusController.close(),
    ]);
    _initialized = false;
    _initializing = false;
  }

  // Get initialization status
  Future<void> get initializationComplete => _initCompleter.future;
}
