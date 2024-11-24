// lib/core/config/firebase_config.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp();
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