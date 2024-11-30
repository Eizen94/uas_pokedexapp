// lib/features/auth/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // Private constructor
  AuthService._();

  // Singleton instance
  static final AuthService instance = AuthService._();

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of auth state changes with error handling
  Stream<User?> get authStateChanges => _auth.authStateChanges().handleError(
        (error) {
          if (kDebugMode) {
            print('❌ Auth state change error: $error');
          }
        },
      );

  // Get current user with null safety
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      if (kDebugMode) {
        print('🔑 Attempting login for email: $email');
      }

      // Input validation
      if (email.isEmpty || password.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-input',
          message: 'Email and password cannot be empty',
        );
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (kDebugMode) {
        print('✅ Login successful for user: ${credential.user?.email}');
      }

      // Update last login time if user exists
      if (credential.user != null) {
        await _updateUserData(credential.user!, {
          'lastLogin': FieldValue.serverTimestamp(),
          'lastLoginDevice': await _getDeviceInfo(),
        });
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      }
      throw _handleAuthError(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected error during login: $e');
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
        print('📝 Attempting registration for email: $email');
      }

      // Input validation
      if (email.isEmpty || password.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-input',
          message: 'Email and password cannot be empty',
        );
      }

      if (password.length < 6) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: 'Password should be at least 6 characters',
        );
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (credential.user != null) {
        // Create initial user data
        await _createUserDocument(credential.user!);
      }

      if (kDebugMode) {
        print('✅ Registration successful for user: ${credential.user?.email}');
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print(
            '❌ Firebase Auth error during registration: ${e.code} - ${e.message}');
      }
      throw _handleAuthError(e);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Unexpected error during registration: $e');
      }
      throw _handleAuthError(e);
    }
  }

  // Sign out with proper cleanup
  Future<void> signOut() async {
    try {
      if (kDebugMode) {
        print('🚪 Attempting sign out for user: ${currentUser?.email}');
      }

      final userId = currentUser?.uid;
      if (userId != null) {
        await _updateUserData(currentUser!, {
          'lastSignOut': FieldValue.serverTimestamp(),
        });
      }

      await _auth.signOut();

      if (kDebugMode) {
        print('✅ Sign out successful');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during sign out: $e');
      }
      throw _handleAuthError(e);
    }
  }

  // Create user document with proper error handling
  Future<void> _createUserDocument(User user) async {
    try {
      if (kDebugMode) {
        print('📝 Creating user document for: ${user.email}');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        final userData = {
          'uid': user.uid,
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'favorites': [],
          'settings': {
            'theme': 'light',
            'language': 'en',
            'notifications': true,
          },
          'deviceInfo': await _getDeviceInfo(),
        };

        await _firestore.collection('users').doc(user.uid).set(userData);

        if (kDebugMode) {
          print('✅ User document created successfully');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error creating user document: $e');
      }
      // Log error but don't throw - user document can be created later
    }
  }

  // Update user data with retry mechanism
  Future<void> _updateUserData(User user, Map<String, dynamic> data) async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        await _firestore.collection('users').doc(user.uid).update(data);
        return;
      } catch (e) {
        retryCount++;
        if (kDebugMode) {
          print('⚠️ Error updating user data (Attempt $retryCount): $e');
        }
        if (retryCount == maxRetries) rethrow;
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
  }

  // Get basic device info for tracking
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    return {
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.toString(),
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  // Unified error handling
  Exception _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      final message = switch (error.code) {
        'user-not-found' => 'No user found with this email',
        'wrong-password' => 'Invalid password',
        'invalid-email' => 'Invalid email format',
        'email-already-in-use' => 'Email is already registered',
        'weak-password' => 'Password is too weak',
        'operation-not-allowed' => 'Operation not allowed',
        'user-disabled' => 'User account has been disabled',
        'invalid-credential' => 'Invalid login credentials',
        'too-many-requests' => 'Too many attempts. Please try again later',
        'network-request-failed' =>
          'Network error. Please check your connection',
        'invalid-input' => error.message ?? 'Invalid input provided',
        _ => error.message ?? 'Authentication error occurred',
      };

      return FirebaseAuthException(
        code: error.code,
        message: message,
      );
    }

    return Exception('An unexpected error occurred: $error');
  }

  // Password reset functionality
  Future<void> resetPassword(String email) async {
    try {
      if (kDebugMode) {
        print('📧 Sending password reset email to: $email');
      }

      await _auth.sendPasswordResetEmail(email: email.trim());

      if (kDebugMode) {
        print('✅ Password reset email sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending password reset email: $e');
      }
      throw _handleAuthError(e);
    }
  }

  // Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoURL);

      // Update Firestore document
      await _updateUserData(user, {
        'displayName': displayName,
        'photoURL': photoURL,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ Profile updated successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating profile: $e');
      }
      throw _handleAuthError(e);
    }
  }

  // Verify email
  Future<void> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      await user.sendEmailVerification();

      if (kDebugMode) {
        print('✅ Verification email sent successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending verification email: $e');
      }
      throw _handleAuthError(e);
    }
  }

  // Delete account with confirmation
  Future<void> deleteAccount(String password) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      // Re-authenticate user before deletion
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete Firestore document first
      await _firestore.collection('users').doc(user.uid).delete();

      // Then delete user account
      await user.delete();

      if (kDebugMode) {
        print('✅ Account deleted successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting account: $e');
      }
      throw _handleAuthError(e);
    }
  }
}
