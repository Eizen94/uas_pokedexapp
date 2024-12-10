// lib/features/auth/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

/// Enhanced user model with proper validation, immutability and type safety
@immutable
class UserModel {
  final String uid;
  final String email;
  final List<String> favorites;
  final DateTime createdAt;
  final Map<String, dynamic> settings;
  final DateTime? lastLogin;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;
  final Map<String, dynamic>? metadata;

  // Constructor with named parameters and validation
  const UserModel({
    required this.uid,
    required this.email,
    required this.favorites,
    required this.createdAt,
    required this.settings,
    this.lastLogin,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
    this.metadata,
  })  : assert(uid.isNotEmpty, 'UID cannot be empty'),
        assert(email.isNotEmpty, 'Email cannot be empty');

  // Factory constructor from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;

      if (data == null) {
        throw const FormatException('Document data is null');
      }

      return UserModel(
        uid: doc.id,
        email: data['email'] as String? ?? '',
        favorites: List<String>.from(data['favorites'] ?? []),
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        settings: Map<String, dynamic>.from(data['settings'] ?? {}),
        lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
        displayName: data['displayName'] as String?,
        photoUrl: data['photoUrl'] as String?,
        emailVerified: data['emailVerified'] as bool? ?? false,
        metadata: data['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error creating UserModel from Firestore: $e');
      }
      rethrow;
    }
  }

  // Factory constructor from Firebase User
  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      favorites: const [],
      createdAt: DateTime.now(),
      settings: const {
        'theme': 'light',
        'language': 'en',
        'notifications': true,
      },
      lastLogin: user.metadata.lastSignInTime,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
      metadata: {
        'creationTime': user.metadata.creationTime?.millisecondsSinceEpoch,
        'lastSignInTime': user.metadata.lastSignInTime?.millisecondsSinceEpoch,
      },
    );
  }

  // Convert to Firestore data
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'favorites': favorites,
      'createdAt': Timestamp.fromDate(createdAt),
      'settings': settings,
      if (lastLogin != null) 'lastLogin': Timestamp.fromDate(lastLogin!),
      if (displayName != null) 'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'emailVerified': emailVerified,
      if (metadata != null) 'metadata': metadata,
    };
  }

  // Create copy with modifications
  UserModel copyWith({
    String? uid,
    String? email,
    List<String>? favorites,
    DateTime? createdAt,
    Map<String, dynamic>? settings,
    DateTime? lastLogin,
    String? displayName,
    String? photoUrl,
    bool? emailVerified,
    Map<String, dynamic>? metadata,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      favorites: favorites ?? List.from(this.favorites),
      createdAt: createdAt ?? this.createdAt,
      settings: settings ?? Map.from(this.settings),
      lastLogin: lastLogin ?? this.lastLogin,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      metadata:
          metadata ?? (this.metadata != null ? Map.from(this.metadata!) : null),
    );
  }

  // Value equality
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          listEquals(favorites, other.favorites) &&
          createdAt == other.createdAt &&
          mapEquals(settings, other.settings) &&
          lastLogin == other.lastLogin &&
          displayName == other.displayName &&
          photoUrl == other.photoUrl &&
          emailVerified == other.emailVerified &&
          mapEquals(metadata, other.metadata);

  @override
  int get hashCode =>
      uid.hashCode ^
      email.hashCode ^
      favorites.hashCode ^
      createdAt.hashCode ^
      settings.hashCode ^
      lastLogin.hashCode ^
      displayName.hashCode ^
      photoUrl.hashCode ^
      emailVerified.hashCode ^
      metadata.hashCode;

  // String representation
  @override
  String toString() => 'UserModel(uid: $uid, email: $email)';

  // Helpers
  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;
  String get displayText => displayName ?? email;
  bool get isComplete => email.isNotEmpty && settings.isNotEmpty;
}
