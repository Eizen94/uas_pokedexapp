// lib/widgets/search_bar.dart

/// Search bar widget with filtering and sorting capabilities.
/// Provides comprehensive Pokemon search and filter functionality.
library;

import 'package:flutter/material.dart';

import '../core/constants/colors.dart';
import '../core/constants/text_styles.dart';
import '../core/utils/string_helper.dart';
import 'pokemon_type_badge.dart';

/// Sort options for Pokemon list
enum PokemonSortOption {
  /// Sort by National Dex number (ascending)
  numberAsc,

  /// Sort by National Dex number (descending)
  numberDesc,

  /// Sort alphabetically A-Z
  nameAsc,

  /// Sort alphabetically Z-A
  nameDesc
}

/// Filter configuration for Pokemon search
class PokemonFilter {
  /// Search query
  final String query;

  /// Selected generation
  final int? generation;

  /// Selected types
  final List<String> types;

  /// Number range min
  final int? minNumber;

  /// Number range max
  final int? maxNumber;

  /// Sort option
  final PokemonSortOption sortOption;

  /// Constructor
  const PokemonFilter({
    this.query = '',
    this.generation,
    this.types = const [],
    this.minNumber,
    this.maxNumber,
    this.sortOption = PokemonSortOption.numberAsc,
  });

  /// Create copy with updated fields
  PokemonFilter copyWith({
    String? query,
    int? generation,
    List<String>? types,
    int? minNumber,
    int? maxNumber,
    PokemonSortOption? sortOption,
  }) {
    return PokemonFilter(
      query: query ?? this.query,
      generation: generation ?? this.generation,
      types: types ?? this.types,
      minNumber: minNumber ?? this.minNumber,
      maxNumber: maxNumber ?? this.maxNumber,
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

/// Search bar widget with filters
class PokemonSearchBar extends StatefulWidget {
  /// Filter changed callback
  final ValueChanged<PokemonFilter> onFilterChanged;

  /// Initial filter state
  final PokemonFilter initialFilter;

  /// Constructor
  const PokemonSearchBar({
    required this.onFilterChanged,
    this.initialFilter = const PokemonFilter(),
    super.key,
  });

  @override
  State<PokemonSearchBar> createState() => _PokemonSearchBarState();
}

class _PokemonSearchBarState extends State<PokemonSearchBar> {
  late final TextEditingController _searchController;
  late PokemonFilter _currentFilter;
  bool _showFilters = false;

  // Pokemon types for filtering
  static const List<String> _pokemonTypes = [
    'Bug',
    'Dark',
    'Dragon',
    'Electric',
    'Fairy',
    'Fighting',
    'Fire',
    'Flying',
    'Ghost',
    'Grass',
    'Ground',
    'Ice',
    'Normal',
    'Poison',
    'Psychic',
    'Rock',
    'Steel',
    'Water'
  ];

  // Available generations
  static const List<int> _generations = [1, 2, 3, 4, 5, 6, 7, 8, 9];

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter;
    _searchController = TextEditingController(text: _currentFilter.query);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final newFilter = _currentFilter.copyWith(
      query: _searchController.text,
    );
    _updateFilter(newFilter);
  }

  void _updateFilter(PokemonFilter filter) {
    setState(() {
      _currentFilter = filter;
    });
    widget.onFilterChanged(filter);
  }

  void _toggleType(String type) {
    final types = List<String>.from(_currentFilter.types);
    if (types.contains(type)) {
      types.remove(type);
    } else {
      types.add(type);
    }
    _updateFilter(_currentFilter.copyWith(types: types));
  }

  void _resetFilters() {
    _searchController.clear();
    _updateFilter(const PokemonFilter());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search input
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search Pokémon',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        ),
                      IconButton(
                        icon: Icon(
                          _showFilters
                              ? Icons.filter_list_off
                              : Icons.filter_list,
                        ),
                        onPressed: () {
                          setState(() {
                            _showFilters = !_showFilters;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Expanded filters
        if (_showFilters)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Generation selector
                Row(
                  children: [
                    Text(
                      'Generation:',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<int?>(
                        value: _currentFilter.generation,
                        hint: const Text('All'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All'),
                          ),
                          ..._generations.map((gen) => DropdownMenuItem(
                                value: gen,
                                child: Text('Generation $gen'),
                              )),
                        ],
                        onChanged: (value) {
                          _updateFilter(_currentFilter.copyWith(
                            generation: value,
                          ));
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Type filters
                Text(
                  'Types:',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _pokemonTypes.map((type) {
                    final isSelected = _currentFilter.types.contains(type);
                    return FilterChip(
                      label: PokemonTypeBadge(
                        type: type,
                        size: BadgeSize.small,
                      ),
                      selected: isSelected,
                      onSelected: (_) => _toggleType(type),
                      backgroundColor: Colors.transparent,
                      selectedColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primaryButton
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Sort options
                Row(
                  children: [
                    Text(
                      'Sort by:',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<PokemonSortOption>(
                        value: _currentFilter.sortOption,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: PokemonSortOption.numberAsc,
                            child: Text('Lowest number first'),
                          ),
                          DropdownMenuItem(
                            value: PokemonSortOption.numberDesc,
                            child: Text('Highest number first'),
                          ),
                          DropdownMenuItem(
                            value: PokemonSortOption.nameAsc,
                            child: Text('A-Z'),
                          ),
                          DropdownMenuItem(
                            value: PokemonSortOption.nameDesc,
                            child: Text('Z-A'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _updateFilter(_currentFilter.copyWith(
                              sortOption: value,
                            ));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Reset button
                Center(
                  child: TextButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Filters'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
      ],
    );
  }
}
