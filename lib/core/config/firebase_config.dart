// lib/core/config/firebase_config.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static Future<void> initializeFirebase() async {
    try {
      // Tambahkan options untuk Android
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey:
              'AIzaSyA788aYkne3gRiwAtZLtsVMRl5reUPMcXg', // dari google-services.json
          appId:
              '1:631128211674:android:f88221525f9e09b7f465e3', // dari google-services.json
          messagingSenderId: '631128211674', // dari google-services.json
          projectId: 'uas-pokedexapp', // dari google-services.json
        ),
      );

      if (kDebugMode) {
        print('🔥 Firebase initialized successfully');
      }

      // Test Firebase Auth
      final auth = FirebaseAuth.instance;
      if (kDebugMode) {
        print('📱 Firebase Auth initialized: ${auth.app.name}');
      }

      // Test Firestore
      final firestore = FirebaseFirestore.instance;
      if (kDebugMode) {
        print('💾 Firestore initialized: ${firestore.app.name}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Firebase: $e');
      }
    }
  }
}
