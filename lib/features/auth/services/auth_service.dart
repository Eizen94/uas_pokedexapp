// lib/features/auth/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AuthService {
  static AuthService? _instance;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // Singleton pattern
  factory AuthService() {
    _instance ??= AuthService._internal(
      FirebaseAuth.instance,
      FirebaseFirestore.instance,
    );
    return _instance!;
  }

  AuthService._internal(this._auth, this._firestore);

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      if (kDebugMode) {
        print('🔑 Attempting login for email: $email');
      }

      // Validate inputs
      _validateInputs(email: email, password: password);

      // Attempt sign in
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (kDebugMode) {
        print('✅ Login successful for user: ${credential.user?.email}');
      }

      // Create or update user document
      if (credential.user != null) {
        await _createOrUpdateUser(credential.user!, {
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
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('❌ Platform error: ${e.code} - ${e.message}');
      }
      // Handle PigeonUserDetails error
      if (e.code == 'ERROR_INVALID_CREDENTIAL') {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'The supplied auth credential is invalid.',
        );
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

      // Validate inputs
      _validateInputs(email: email, password: password);

      // Check password strength
      if (password.length < 6) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: 'Password should be at least 6 characters',
        );
      }

      // Attempt registration
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (credential.user != null) {
        // Create initial user document
        await _createOrUpdateUser(credential.user!, {
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'favorites': [],
          'settings': {
            'theme': 'light',
            'language': 'en',
            'notifications': true,
          },
          'deviceInfo': await _getDeviceInfo(),
        });
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
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('❌ Platform error: ${e.code} - ${e.message}');
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
      final user = currentUser;
      if (kDebugMode) {
        print('🚪 Attempting sign out for user: ${user?.email}');
      }

      if (user != null) {
        try {
          // Try to update the user document
          await _createOrUpdateUser(user, {
            'lastSignOut': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          // Log but don't throw - we still want to sign out
          if (kDebugMode) {
            print('⚠️ Warning: Could not update last sign out time: $e');
          }
        }
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

  // Create or update user document
  Future<void> _createOrUpdateUser(User user, Map<String, dynamic> data) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        // Update existing document
        await userRef.update(data);
      } else {
        // Create new document
        await userRef.set({
          'uid': user.uid,
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'favorites': [],
          'settings': {
            'theme': 'light',
            'language': 'en',
            'notifications': true,
          },
          ...data,
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error updating user document: $e');
      }
      // We don't throw here - document operations should not block auth
    }
  }

  // Get device info for tracking
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    return {
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.toString(),
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  // Input validation
  void _validateInputs({required String email, required String password}) {
    if (email.isEmpty || password.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-input',
        message: 'Email and password cannot be empty',
      );
    }

    if (!email.contains('@')) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Please enter a valid email address',
      );
    }
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

    if (error is PlatformException) {
      return FirebaseAuthException(
        code: error.code,
        message: error.message ?? 'Platform error occurred',
      );
    }

    return Exception('An unexpected error occurred: $error');
  }

  // User document operations
  Future<DocumentSnapshot?> getUserDocument() async {
    try {
      final user = currentUser;
      if (user != null) {
        return await _firestore.collection('users').doc(user.uid).get();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting user document: $e');
      }
      return null;
    }
  }

  // Update user settings
  Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    try {
      final user = currentUser;
      if (user != null) {
        await _createOrUpdateUser(user, {
          'settings': settings,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating user settings: $e');
      }
      throw _handleAuthError(e);
    }
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Delete account
  Future<void> deleteAccount(String password) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      // Re-authenticate before deletion
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete user document first
      try {
        await _firestore.collection('users').doc(user.uid).delete();
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Warning: Could not delete user document: $e');
        }
      }

      // Delete user account
      await user.delete();
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // User settings stream
  Stream<DocumentSnapshot> userSettingsStream() {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }
    return _firestore.collection('users').doc(user.uid).snapshots();
  }
}
