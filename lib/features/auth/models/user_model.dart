// lib/features/auth/models/user_model.dart

/// User model to represent application user data.
/// Handles user data conversion and validation.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

/// User model class
@JsonSerializable()
class UserModel {
  /// Unique user identifier
  final String id;

  /// User's email address
  final String email;

  /// User's display name
  final String? displayName;

  /// User's photo URL
  final String? photoUrl;

  /// Email verification status
  final bool isEmailVerified;

  /// Account creation timestamp
  final DateTime createdAt;

  /// Last login timestamp
  final DateTime? lastLoginAt;

  /// Custom user settings
  final UserSettings settings;

  /// Constructor
  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.isEmailVerified,
    required this.createdAt,
    this.lastLoginAt,
    required this.settings,
  });

  /// Create from Firebase User
  factory UserModel.fromFirebaseUser(User user) => UserModel(
        id: user.uid,
        email: user.email!,
        displayName: user.displayName,
        photoUrl: user.photoURL,
        isEmailVerified: user.emailVerified,
        createdAt: user.metadata.creationTime ?? DateTime.now(),
        lastLoginAt: user.metadata.lastSignInTime,
        settings: UserSettings(),
      );

  /// Create from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  /// Create copy with updated fields
  UserModel copyWith({
    String? displayName,
    String? photoUrl,
    bool? isEmailVerified,
    DateTime? lastLoginAt,
    UserSettings? settings,
  }) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      settings: settings ?? this.settings,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          displayName == other.displayName &&
          photoUrl == other.photoUrl &&
          isEmailVerified == other.isEmailVerified &&
          createdAt == other.createdAt &&
          lastLoginAt == other.lastLoginAt &&
          settings == other.settings;

  @override
  int get hashCode =>
      id.hashCode ^
      email.hashCode ^
      displayName.hashCode ^
      photoUrl.hashCode ^
      isEmailVerified.hashCode ^
      createdAt.hashCode ^
      lastLoginAt.hashCode ^
      settings.hashCode;

  @override
  String toString() => 'UserModel('
      'id: $id, '
      'email: $email, '
      'displayName: $displayName, '
      'photoUrl: $photoUrl, '
      'isEmailVerified: $isEmailVerified, '
      'createdAt: $createdAt, '
      'lastLoginAt: $lastLoginAt, '
      'settings: $settings)';
}

/// User settings model
@JsonSerializable()
class UserSettings {
  /// Theme preference
  final bool isDarkMode;

  /// Language preference
  final String language;

  /// Notification settings
  final NotificationSettings notifications;

  /// Constructor
  const UserSettings({
    this.isDarkMode = false,
    this.language = 'en',
    this.notifications = const NotificationSettings(),
  });

  /// Create from JSON
  factory UserSettings.fromJson(Map<String, dynamic> json) =>
      _$UserSettingsFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$UserSettingsToJson(this);

  /// Create copy with updated fields
  UserSettings copyWith({
    bool? isDarkMode,
    String? language,
    NotificationSettings? notifications,
  }) {
    return UserSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      language: language ?? this.language,
      notifications: notifications ?? this.notifications,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettings &&
          runtimeType == other.runtimeType &&
          isDarkMode == other.isDarkMode &&
          language == other.language &&
          notifications == other.notifications;

  @override
  int get hashCode =>
      isDarkMode.hashCode ^ language.hashCode ^ notifications.hashCode;
}

/// Notification settings model
@JsonSerializable()
class NotificationSettings {
  /// Push notifications enabled
  final bool pushEnabled;

  /// Email notifications enabled
  final bool emailEnabled;

  /// Constructor
  const NotificationSettings({
    this.pushEnabled = true,
    this.emailEnabled = true,
  });

  /// Create from JSON
  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      _$NotificationSettingsFromJson(json);

  /// Convert to JSON
  Map<String, dynamic> toJson() => _$NotificationSettingsToJson(this);

  /// Create copy with updated fields
  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSettings &&
          runtimeType == other.runtimeType &&
          pushEnabled == other.pushEnabled &&
          emailEnabled == other.emailEnabled;

  @override
  int get hashCode => pushEnabled.hashCode ^ emailEnabled.hashCode;
}
