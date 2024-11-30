// lib/features/auth/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  User? _currentUser;
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      if (kDebugMode) {
        print('🔄 Loading user data...');
      }

      _currentUser = _authService.currentUser;

      if (kDebugMode && _currentUser != null) {
        print('✅ User data loaded: ${_currentUser!.email}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading user data: $e');
      }
      _showError('Failed to load user data');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      setState(() => _isSyncing = true);

      if (kDebugMode) {
        print('🚪 Attempting to sign out...');
      }

      await _authService.signOut();

      if (mounted) {
        if (kDebugMode) {
          print('✅ Sign out successful');
        }
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Sign out error: $e');
      }
      _showError('Failed to sign out');
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadUserData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _isSyncing ? null : _signOut,
          ),
        ],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Hero(
                      tag: 'profile_avatar',
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _currentUser?.email ?? 'No Email',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 32),
                    _buildProfileSection(
                      title: 'Account Info',
                      icon: Icons.person_outline,
                      children: [
                        _buildInfoTile(
                          icon: Icons.email,
                          title: 'Email',
                          subtitle: _currentUser?.email ?? 'No Email',
                        ),
                        _buildInfoTile(
                          icon: Icons.access_time,
                          title: 'Joined',
                          subtitle:
                              _currentUser?.metadata.creationTime?.toString() ??
                                  'Unknown',
                        ),
                        _buildInfoTile(
                          icon: Icons.verified_user,
                          title: 'Email Verified',
                          subtitle: _currentUser?.emailVerified ?? false
                              ? 'Verified'
                              : 'Not Verified',
                          trailing: _currentUser?.emailVerified ?? false
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : TextButton(
                                  onPressed: () async {
                                    try {
                                      await _authService
                                          .sendEmailVerification();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Verification email sent. Please check your inbox.',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      _showError(
                                          'Failed to send verification email');
                                    }
                                  },
                                  child: const Text('Verify Now'),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildProfileSection(
                      title: 'App Settings',
                      icon: Icons.settings_outlined,
                      children: [
                        SwitchListTile(
                          title: const Text('Dark Mode'),
                          secondary: const Icon(Icons.dark_mode),
                          value:
                              Theme.of(context).brightness == Brightness.dark,
                          onChanged: (bool value) {
                            // TODO: Implement theme switching
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.language),
                          title: const Text('Language'),
                          subtitle: const Text('English'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // TODO: Implement language selection
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.notifications),
                          title: const Text('Notifications'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // TODO: Implement notifications settings
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildProfileSection(
                      title: 'About',
                      icon: Icons.info_outline,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.update),
                          title: const Text('Version'),
                          subtitle: const Text('1.0.0'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.policy),
                          title: const Text('Privacy Policy'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // TODO: Implement privacy policy
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.description),
                          title: const Text('Terms of Service'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // TODO: Implement terms of service
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isSyncing ? null : _signOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.logout),
                      label: Text(
                        _isSyncing ? 'Signing out...' : 'Sign Out',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
      ),
      trailing: trailing,
    );
  }
}
