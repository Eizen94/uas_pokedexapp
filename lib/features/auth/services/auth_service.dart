// lib/features/auth/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/config/firebase_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

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
      if (kDebugMode) {
        print('📱 Attempting login for email: $email');
      }

      if (!FirebaseConfig.isInitialized) {
        if (kDebugMode) {
          print('🔄 Firebase not initialized, initializing...');
        }
        await FirebaseConfig.initializeFirebase();
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        print('✅ Login successful for user: ${credential.user?.email}');
      }

      // Update last login time
      if (credential.user != null) {
        await _updateLastLogin(credential.user!);
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
      if (kDebugMode) {
        print('📱 Attempting registration for email: $email');
      }

      if (!FirebaseConfig.isInitialized) {
        if (kDebugMode) {
          print('🔄 Firebase not initialized, initializing...');
        }
        await FirebaseConfig.initializeFirebase();
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _createUserDocument(credential.user!);
      }

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
      if (kDebugMode) {
        print('📝 Creating user document for: ${user.email}');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'createdAt': Timestamp.now(),
          'favorites': [],
          'lastLogin': Timestamp.now(),
          'settings': {
            'theme': 'light',
            'language': 'en',
          }
        });

        if (kDebugMode) {
          print('✅ User document created successfully');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating user document: $e');
      }
      // Don't throw here as this is not critical for auth flow
    }
  }

  // Update last login time
  Future<void> _updateLastLogin(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'lastLogin': Timestamp.now(),
      });

      if (kDebugMode) {
        print('✅ Last login time updated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating last login: $e');
      }
      // Don't throw as this is not critical
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
        'invalid-credential' => 'Data login tidak valid',
        'user-disabled' => 'Akun telah dinonaktifkan',
        _ => 'Terjadi kesalahan: ${e.message}',
      };
    }
    return 'Terjadi kesalahan yang tidak diketahui';
  }
}
