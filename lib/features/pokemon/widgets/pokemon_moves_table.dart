// lib/features/pokemon/widgets/pokemon_moves_table.dart

import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../widgets/pokemon_type_badge.dart';

class PokemonMovesTable extends StatefulWidget {
  final List<String> moves;

  const PokemonMovesTable({
    super.key,
    required this.moves,
  });

  @override
  State<PokemonMovesTable> createState() => _PokemonMovesTableState();
}

class _PokemonMovesTableState extends State<PokemonMovesTable> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'Name';
  bool _ascending = true;

  final List<String> _categories = ['All', 'Physical', 'Special', 'Status'];
  final List<String> _sortOptions = ['Name', 'Power', 'Accuracy', 'PP'];

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildFilters(),
          _buildMovesList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Moves',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${widget.moves.length} moves',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
            decoration: InputDecoration(
              hintText: 'Search moves...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Category and Sort Filters
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  value: _selectedCategory,
                  items: _categories,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                  hint: 'Category',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown(
                  value: _sortBy,
                  items: _sortOptions,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        if (_sortBy == value) {
                          _ascending = !_ascending;
                        } else {
                          _sortBy = value;
                          _ascending = true;
                        }
                      });
                    }
                  },
                  hint: 'Sort by',
                  trailing: Icon(
                    _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?)? onChanged,
    required String hint,
    Widget? trailing,
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
        icon: trailing ?? const Icon(Icons.arrow_drop_down),
      ),
    );
  }

  Widget _buildMovesList() {
    final filteredMoves = widget.moves.where((move) {
      final matchesSearch = move.toLowerCase().contains(_searchQuery);
      if (_selectedCategory == 'All') return matchesSearch;
      // TODO: Implement category filtering when move details are available
      return matchesSearch;
    }).toList();

    // Sort moves
    filteredMoves.sort((a, b) {
      if (_ascending) {
        return a.compareTo(b);
      } else {
        return b.compareTo(a);
      }
      // TODO: Implement sorting by other criteria when move details are available
    });

    if (filteredMoves.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text('No moves found'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredMoves.length,
      itemBuilder: (context, index) {
        final move = filteredMoves[index];
        return _buildMoveItem(move);
      },
    );
  }

  Widget _buildMoveItem(String move) {
    return ListTile(
      title: Text(
        _formatMoveName(move),
        style: AppTextStyles.titleMedium.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Row(
        children: [
          // TODO: Add move type badge when move details are available
          PokemonTypeBadge.small(type: 'normal'),
          const SizedBox(width: 8),
          // TODO: Add move category (physical/special/status) when details are available
          const Icon(
            Icons.fitness_center,
            size: 16,
            color: Colors.grey,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // TODO: Add actual values when move details are available
          _buildStatChip('Power', '80'),
          const SizedBox(width: 8),
          _buildStatChip('PP', '20'),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $value',
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatMoveName(String move) {
    return move
        .split('-')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

/// Example usage:
///```dart
/// PokemonMovesTable(
///   moves: pokemon.moves,
/// )
///```