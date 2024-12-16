// lib/features/favorites/screens/favorites_screen.dart

/// Favorites screen to display user's favorite Pokemon.
/// Manages favorite Pokemon list and interactions.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../widgets/error_dialog.dart';
import '../../../widgets/loading_indicator.dart';
import '../../auth/models/user_model.dart';
import '../../pokemon/screens/pokemon_detail_screen.dart';
import '../../pokemon/widgets/pokemon_card.dart';
import '../models/favorite_model.dart';
import '../services/favorite_service.dart';

/// Favorites screen widget
class FavoritesScreen extends StatefulWidget {
  /// Current user
  final UserModel user;

  /// Constructor
  const FavoritesScreen({
    required this.user,
    super.key,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final FavoriteService _favoriteService;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      _favoriteService = await FavoriteService.initialize();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initialize favorites: $e';
        });
      }
    }
  }

  Future<void> _removeFavorite(FavoriteModel favorite) async {
    try {
      await _favoriteService.removeFromFavorites(
        userId: widget.user.id,
        favoriteId: favorite.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${favorite.pokemon.name} from favorites'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  await _favoriteService.addToFavorites(
                    userId: widget.user.id,
                    pokemon: favorite.pokemon,
                    note: favorite.note,
                    nickname: favorite.nickname,
                  );
                } catch (e) {
                  if (mounted) {
                    ErrorDialog.show(
                      context: context,
                      message: 'Failed to restore favorite: $e',
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(
          context: context,
          message: 'Failed to remove favorite: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingIndicator();
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeService,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: StreamBuilder<List<FavoriteModel>>(
        stream: _favoriteService.getFavoritesStream(widget.user.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading favorites: ${snapshot.error}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const LoadingIndicator();
          }

          final favorites = snapshot.data!;

          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No favorites yet',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your favorite Pokémon will appear here',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.secondaryText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final favorite = favorites[index];
              return PokemonCard(
                pokemon: favorite.pokemon,
                isFavorite: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PokemonDetailScreen(
                        pokemon: favorite.pokemon,
                        user: widget.user,
                      ),
                    ),
                  );
                },
                onFavorite: () => _removeFavorite(favorite),
              );
            },
          );
        },
      ),
    );
  }
}
