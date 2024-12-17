// lib/navigation/bottom_navigation.dart

/// Bottom navigation bar widget for main app navigation.
/// Handles tab switching and maintains navigation state.
library;

import 'package:flutter/material.dart';

import '../core/constants/colors.dart';
import '../features/auth/models/user_model.dart';
import '../features/auth/screens/profile_screen.dart';
import '../features/favorites/screens/favorites_screen.dart';
import '../features/pokemon/screens/pokemon_list_screen.dart';

/// Main bottom navigation bar
class MainBottomNavigation extends StatefulWidget {
  /// Current user
  final UserModel user;

  /// Constructor
  const MainBottomNavigation({
    required this.user,
    super.key,
  });

  @override
  State<MainBottomNavigation> createState() => _MainBottomNavigationState();
}

class _MainBottomNavigationState extends State<MainBottomNavigation> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _screens = [
      PokemonListScreen(user: widget.user),
      FavoritesScreen(user: widget.user),
      const ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        physics: const NeverScrollableScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primaryButton,
          unselectedItemColor: AppColors.secondaryText,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.catching_pokemon_outlined),
              activeIcon: Icon(Icons.catching_pokemon),
              label: 'Pokédex',
              tooltip: 'Browse Pokémon',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_outline),
              activeIcon: Icon(Icons.favorite),
              label: 'Favorites',
              tooltip: 'Your favorite Pokémon',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
              tooltip: 'Your profile',
            ),
          ],
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          elevation: 0,
        ),
      ),
    );
  }
}
