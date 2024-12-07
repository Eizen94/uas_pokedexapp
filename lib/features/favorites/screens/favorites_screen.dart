// lib/features/favorites/screens/favorites_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/favorite_model.dart';
import '../../../services/firebase_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/error_dialog.dart';
import '../../../features/pokemon/widgets/pokemon_type_badge.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  Stream<List<FavoriteModel>>? _favoritesStream;

  @override
  void initState() {
    super.initState();
    _initializeFavorites();
  }

  void _initializeFavorites() {
    final user = context.read<AppAuthProvider>().user;
    if (user != null) {
      setState(() {
        _favoritesStream = _firebaseService.getUserFavorites(user.uid);
      });
    }
  }

  Future<void> _removeFavorite(String userId, FavoriteModel favorite) async {
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Favorite'),
          content: Text(
            'Are you sure you want to remove ${favorite.pokemonName} from favorites?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _firebaseService.removeFromFavorites(
                  userId,
                  favorite.id,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${favorite.pokemonName} removed from favorites',
                      ),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error removing favorite: $e');
      }
      if (mounted) {
        ErrorDialog.show(
          context,
          title: 'Error',
          message: 'Failed to remove from favorites. Please try again.',
        );
      }
    }
  }

  void _navigateToPokemonDetail(BuildContext context, int pokemonId) {
    Navigator.pushNamed(
      context,
      '/pokemon/detail',
      arguments: {'id': pokemonId},
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No favorites yet',
            style: AppTextStyles.titleMedium.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pokemon you favorite will appear here',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/home'),
            icon: const Icon(Icons.catching_pokemon),
            label: const Text('Discover Pokemon'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(
    BuildContext context,
    FavoriteModel favorite,
    String userId,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToPokemonDetail(context, favorite.pokemonId),
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.getTypeColor(favorite.pokemonTypes.first)
                        .withOpacity(0.7),
                    AppColors.getTypeColor(favorite.pokemonTypes.first)
                        .withOpacity(0.5),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '#${favorite.pokemonId.toString().padLeft(3, '0')}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.favorite,
                            color: Colors.white,
                          ),
                          onPressed: () => _removeFavorite(userId, favorite),
                        ),
                      ],
                    ),
                    Hero(
                      tag: 'favorite-${favorite.pokemonId}',
                      child: CachedNetworkImage(
                        imageUrl: favorite.imageUrl,
                        height: 120,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const SizedBox(
                          height: 120,
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => const SizedBox(
                          height: 120,
                          child: Center(
                            child: Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      favorite.pokemonName,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: favorite.pokemonTypes
                          .map(
                            (type) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: PokemonTypeBadge.small(
                                type: type,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppAuthProvider>().user;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Please login to view favorites',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Favorites',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<FavoriteModel>>(
        stream: _favoritesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: LoadingIndicator(
                message: 'Loading favorites...',
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading favorites',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _initializeFavorites,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final favorites = snapshot.data ?? [];

          if (favorites.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => _initializeFavorites(),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final favorite = favorites[index];
                return _buildFavoriteCard(
                  context,
                  favorite,
                  user.uid,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
