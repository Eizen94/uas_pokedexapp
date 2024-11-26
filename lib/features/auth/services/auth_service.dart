import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/config/firebase_config.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Ensure Firebase is initialized
      if (!FirebaseConfig.isInitialized) {
        await FirebaseConfig.initializeFirebase();
      }

      if (kDebugMode) {
        print('📱 Attempting login for email: $email');
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        print('✅ Login successful for user: ${credential.user?.email}');
      }

      return credential;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Login error: $e');
      }
      throw _handleAuthError(e);
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Ensure Firebase is initialized
      if (!FirebaseConfig.isInitialized) {
        await FirebaseConfig.initializeFirebase();
      }

      if (kDebugMode) {
        print('📱 Attempting registration for email: $email');
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _createUserDocument(credential.user!);

      if (kDebugMode) {
        print('✅ Registration successful for user: ${credential.user?.email}');
      }

      return credential;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Registration error: $e');
      }
      throw _handleAuthError(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      if (kDebugMode) {
        print('📱 Attempting sign out for user: ${currentUser?.email}');
      }

      await _auth.signOut();

      if (kDebugMode) {
        print('✅ Sign out successful');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sign out error: $e');
      }
      throw _handleAuthError(e);
    }
  }

  // Create user document
  Future<void> _createUserDocument(User user) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'createdAt': Timestamp.now(),
          'favorites': [],
          'lastLogin': Timestamp.now(),
        });

        if (kDebugMode) {
          print('✅ User document created successfully');
        }
      } else {
        // Update lastLogin time
        await _firestore.collection('users').doc(user.uid).update({
          'lastLogin': Timestamp.now(),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating/updating user document: $e');
      }
      // Don't throw here as this is not critical for auth flow
    }
  }

  // Handle Firebase Auth errors
  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'weak-password' => 'Password terlalu lemah',
        'email-already-in-use' => 'Email sudah terdaftar',
        'invalid-email' => 'Email tidak valid',
        'user-not-found' => 'User tidak ditemukan',
        'wrong-password' => 'Password salah',
        'operation-not-allowed' => 'Operasi tidak diizinkan',
        'too-many-requests' => 'Terlalu banyak percobaan. Coba lagi nanti',
        'network-request-failed' => 'Koneksi internet bermasalah',
        _ => 'Terjadi kesalahan: ${e.message}',
      };
    }
    return 'Terjadi kesalahan yang tidak diketahui';
  }
}
