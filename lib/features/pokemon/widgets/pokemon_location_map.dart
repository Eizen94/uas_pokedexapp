// lib/features/pokemon/widgets/pokemon_location_map.dart

import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';

class PokemonLocationMap extends StatefulWidget {
  final int pokemonId;
  final List<PokemonLocation> locations;

  const PokemonLocationMap({
    super.key,
    required this.pokemonId,
    required this.locations,
  });

  @override
  State<PokemonLocationMap> createState() => _PokemonLocationMapState();
}

class PokemonLocation {
  final String region;
  final String area;
  final String method;
  final List<GameVersion> versions;
  final int rarity;
  final String? condition;
  final List<String> levelRange;

  const PokemonLocation({
    required this.region,
    required this.area,
    required this.method,
    required this.versions,
    required this.rarity,
    this.condition,
    required this.levelRange,
  });
}

enum GameVersion {
  red,
  blue,
  yellow,
  gold,
  silver,
  crystal,
  ruby,
  sapphire,
  emerald,
  firered,
  leafgreen,
  diamond,
  pearl,
  platinum,
  heartgold,
  soulsilver,
  black,
  white,
  black2,
  white2,
  x,
  y,
  omegaruby,
  alphasapphire,
  sun,
  moon,
  ultrasun,
  ultramoon,
  sword,
  shield
}

class _PokemonLocationMapState extends State<PokemonLocationMap> {
  String _selectedRegion = 'All';
  String _selectedVersion = 'All';

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (widget.locations.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildFilters(),
              const SizedBox(height: 16),
              _buildLocationList(),
            ] else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Locations',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '${widget.locations.length} areas',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final regions = ['All', ...widget.locations.map((l) => l.region).toSet()];
    final versions = [
      'All',
      ...widget.locations
          .expand((l) => l.versions)
          .map((v) => v.toString().split('.').last)
          .toSet(),
    ];

    return Row(
      children: [
        Expanded(
          child: _buildDropdown(
            value: _selectedRegion,
            items: regions,
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedRegion = value);
              }
            },
            hint: 'Region',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildDropdown(
            value: _selectedVersion,
            items: versions,
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedVersion = value);
              }
            },
            hint: 'Version',
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?)? onChanged,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: value,
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
        hint: Text(hint),
        underline: const SizedBox(),
        isExpanded: true,
      ),
    );
  }

  Widget _buildLocationList() {
    final filteredLocations = widget.locations.where((location) {
      final matchesRegion =
          _selectedRegion == 'All' || location.region == _selectedRegion;
      final matchesVersion = _selectedVersion == 'All' ||
          location.versions.any((v) =>
              v.toString().split('.').last.toLowerCase() ==
              _selectedVersion.toLowerCase());
      return matchesRegion && matchesVersion;
    }).toList();

    if (filteredLocations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No locations found for selected filters',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredLocations.length,
      itemBuilder: (context, index) {
        final location = filteredLocations[index];
        return _buildLocationItem(location);
      },
    );
  }

  Widget _buildLocationItem(PokemonLocation location) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: ExpansionTile(
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Icon(
                _getRegionIcon(location.region),
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.area,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      location.region,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getRarityColor(location.rarity).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${location.rarity}%',
                  style: AppTextStyles.caption.copyWith(
                    color: _getRarityColor(location.rarity),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Row(
              children: [
                _buildInfoColumn(
                  'Method',
                  location.method,
                  Icons.catching_pokemon,
                ),
                const SizedBox(width: 16),
                _buildInfoColumn(
                  'Level Range',
                  location.levelRange.join('-'),
                  Icons.trending_up,
                ),
                if (location.condition != null) ...[
                  const SizedBox(width: 16),
                  _buildInfoColumn(
                    'Condition',
                    location.condition!,
                    Icons.info_outline,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _buildVersionChips(location.versions),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVersionChips(List<GameVersion> versions) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: versions.map((version) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: _getVersionColor(version).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            version.toString().split('.').last,
            style: AppTextStyles.caption.copyWith(
              color: _getVersionColor(version),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No location data available',
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This Pokemon might be obtained through special events or trades',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRegionIcon(String region) {
    switch (region.toLowerCase()) {
      case 'kanto':
        return Icons.looks_one;
      case 'johto':
        return Icons.looks_two;
      case 'hoenn':
        return Icons.looks_3;
      case 'sinnoh':
        return Icons.looks_4;
      case 'unova':
        return Icons.looks_5;
      case 'kalos':
        return Icons.looks_6;
      case 'alola':
        return Icons.filter_7;
      case 'galar':
        return Icons.filter_8;
      default:
        return Icons.public;
    }
  }

  Color _getRarityColor(int rarity) {
    if (rarity <= 5) return Colors.red[700]!;
    if (rarity <= 10) return Colors.orange[700]!;
    if (rarity <= 20) return Colors.yellow[700]!;
    if (rarity <= 40) return Colors.green[700]!;
    return Colors.blue[700]!;
  }

  Color _getVersionColor(GameVersion version) {
    switch (version) {
      case GameVersion.red:
      case GameVersion.ruby:
      case GameVersion.firered:
      case GameVersion.omegaruby:
        return Colors.red[700]!;
      case GameVersion.blue:
      case GameVersion.sapphire:
      case GameVersion.alphasapphire:
        return Colors.blue[700]!;
      case GameVersion.yellow:
        return Colors.yellow[700]!;
      case GameVersion.gold:
      case GameVersion.heartgold:
        return Colors.orange[700]!;
      case GameVersion.silver:
      case GameVersion.soulsilver:
        return Colors.grey[700]!;
      case GameVersion.crystal:
        return Colors.cyan[700]!;
      case GameVersion.emerald:
        return Colors.green[700]!;
      case GameVersion.leafgreen:
        return Colors.lightGreen[700]!;
      case GameVersion.diamond:
      case GameVersion.pearl:
      case GameVersion.platinum:
        return Colors.purple[700]!;
      case GameVersion.black:
      case GameVersion.black2:
        return Colors.grey[900]!;
      case GameVersion.white:
      case GameVersion.white2:
        return Colors.grey[300]!;
      case GameVersion.x:
        return Colors.indigoAccent[700]!;
      case GameVersion.y:
        return Colors.redAccent[700]!;
      case GameVersion.sun:
      case GameVersion.ultrasun:
        return Colors.orange[300]!;
      case GameVersion.moon:
      case GameVersion.ultramoon:
        return Colors.deepPurple[700]!;
      case GameVersion.sword:
        return Colors.blue[300]!;
      case GameVersion.shield:
        return Colors.red[300]!;
      default:
        return Colors.grey[700]!;
    }
  }
}

/// Example usage:
///```dart
/// PokemonLocationMap(
///   pokemonId: pokemon.id,
///   locations: [
///     PokemonLocation(
///       region: 'Kanto',
///       area: 'Viridian Forest',
///       method: 'Walking in grass',
///       versions: [GameVersion.red, GameVersion.blue],
///       rarity: 25,
///       levelRange: ['3', '5'],
///     ),
///   ],
/// )
///```