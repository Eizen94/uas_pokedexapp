import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String email;
  final List<String> favorites;
  final DateTime createdAt;
  final Map<String, dynamic> settings;

  UserModel({
    required this.uid,
    required this.email,
    required this.favorites,
    required this.createdAt,
    this.settings = const {},
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      favorites: List<String>.from(json['favorites'] ?? []),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel.fromJson({'uid': doc.id, ...data});
  }

  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      favorites: [],
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'favorites': favorites,
        'createdAt': Timestamp.fromDate(createdAt),
        'settings': settings,
      };

  UserModel copyWith({
    String? uid,
    String? email,
    List<String>? favorites,
    DateTime? createdAt,
    Map<String, dynamic>? settings,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      favorites: favorites ?? this.favorites,
      createdAt: createdAt ?? this.createdAt,
      settings: settings ?? this.settings,
    );
  }

  @override
  String toString() => 'UserModel(uid: $uid, email: $email)';
}
