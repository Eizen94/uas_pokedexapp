// lib/core/config/firebase_config.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      
      // Optional: Enable Firestore offline persistence
      // FirebaseFirestore.instance.settings = 
      //   const Settings(persistenceEnabled: true, cacheSizeBytes: 5242880);
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Firebase: $e');
      }
    }
  }
}