// lib/features/pokemon/widgets/pokemon_image_gallery.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';

class PokemonImageGallery extends StatefulWidget {
  final int pokemonId;
  final String defaultImage;
  final bool showShiny;

  const PokemonImageGallery({
    super.key,
    required this.pokemonId,
    required this.defaultImage,
    this.showShiny = true,
  });

  @override
  State<PokemonImageGallery> createState() => _PokemonImageGalleryState();
}

class _PokemonImageGalleryState extends State<PokemonImageGallery>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;
  bool _isShowingShiny = false;

  final List<String> _viewTypes = [
    'Official Art',
    'Home',
    '3D Model',
    'Sprites'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _viewTypes.length,
      vsync: this,
    );
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.index != _currentIndex) {
      setState(() => _currentIndex = _tabController.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabs(),
        const SizedBox(height: 16),
        _buildImageView(),
        if (widget.showShiny) _buildShinyToggle(),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppColors.primary,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: AppTextStyles.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
        ),
        tabs: _viewTypes.map((type) => Tab(text: type)).toList(),
      ),
    );
  }

  Widget _buildImageView() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOfficialArtwork(),
            _buildHomeImage(),
            _build3DModel(),
            _buildSpritesGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialArtwork() {
    final imageUrl = _isShowingShiny
        ? 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/shiny/${widget.pokemonId}.png'
        : widget.defaultImage;

    return _buildImageContainer(imageUrl);
  }

  Widget _buildHomeImage() {
    final imageUrl = _isShowingShiny
        ? 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/shiny/${widget.pokemonId}.png'
        : 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/${widget.pokemonId}.png';

    return _buildImageContainer(imageUrl);
  }

  Widget _build3DModel() {
    final imageUrl = _isShowingShiny
        ? 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/shiny/${widget.pokemonId}.gif'
        : 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/${widget.pokemonId}.gif';

    return _buildImageContainer(imageUrl);
  }

  Widget _buildSpritesGrid() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildSpriteItem('Front', 'normal', false),
        _buildSpriteItem('Back', 'back', false),
        if (_isShowingShiny) ...[
          _buildSpriteItem('Front Shiny', 'normal', true),
          _buildSpriteItem('Back Shiny', 'back', true),
        ],
      ],
    );
  }

  Widget _buildSpriteItem(String label, String position, bool shiny) {
    final baseUrl =
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';
    final shinyPath = shiny ? '/shiny' : '';
    final backPath = position == 'back' ? '/back' : '';
    final imageUrl = '$baseUrl$shinyPath$backPath/${widget.pokemonId}.png';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: _buildImageContainer(imageUrl),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildImageContainer(String imageUrl) {
    return Center(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(
            Icons.broken_image_rounded,
            size: 48,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildShinyToggle() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Shiny Form',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: _isShowingShiny,
            onChanged: (value) {
              setState(() => _isShowingShiny = value);
            },
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
