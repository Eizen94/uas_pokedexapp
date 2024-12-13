// lib/features/auth/screens/profile_screen.dart

/// Profile screen to display and manage user profile information.
/// Handles user profile updates and sign out functionality.
library features.auth.screens.profile_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../../favorites/services/favorite_service.dart';

/// Profile screen widget
class ProfileScreen extends StatefulWidget {
  /// Constructor
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  late final AuthService _authService;
  late final UserModel _currentUser; // Remove ? since we check in initState

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      throw StateError('User must be logged in to view profile');
    }
    _currentUser = user;
    _displayNameController.text = _currentUser.displayName ?? '';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.updateProfile(
        displayName: _displayNameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signOut();
      // Navigation will be handled by auth state changes
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleVerifyEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.verifyEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent. Please check your inbox.'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _isLoading ? null : _handleSignOut,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile header
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primaryButton,
                child: Text(
                  (_currentUser.displayName?.isNotEmpty == true)
                      ? _currentUser.displayName!.toUpperCase()[0]
                      : _currentUser.email[0].toUpperCase(),
                  style: AppTextStyles.heading1.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),

              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Email display
              Card(
                child: ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(_currentUser.email),
                  subtitle: Text(
                    _currentUser.isEmailVerified ? 'Verified' : 'Not verified',
                    style: TextStyle(
                      color: _currentUser.isEmailVerified
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                  trailing: !_currentUser.isEmailVerified
                      ? TextButton(
                          onPressed: _isLoading ? null : _handleVerifyEmail,
                          child: const Text('Verify'),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Display name field
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'Enter your display name',
                  prefixIcon: Icon(Icons.person_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your display name';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),

              // Update button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleUpdateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryButton,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Update Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),

              const SizedBox(height: 32),

              // Preferences section
              const Text('Preferences',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Theme toggle
              Card(
                child: ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('Dark Mode'),
                  trailing: Switch(
                    value: _currentUser.settings.isDarkMode,
                    onChanged: _isLoading
                        ? null
                        : (bool value) {
                            // Theme toggle will be handled by theme provider
                          },
                  ),
                ),
              ),

              // Language selection
              Card(
                child: ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Language'),
                  subtitle: Text(_currentUser.settings.language.toUpperCase()),
                  onTap: _isLoading
                      ? null
                      : () {
                          // Language selection will be implemented later
                        },
                ),
              ),

              // Notification settings
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  subtitle: Text(
                    _currentUser.settings.notifications.pushEnabled
                        ? 'Enabled'
                        : 'Disabled',
                  ),
                  trailing: Switch(
                    value: _currentUser.settings.notifications.pushEnabled,
                    onChanged: _isLoading
                        ? null
                        : (bool value) {
                            // Notification toggle will be handled by settings provider
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
