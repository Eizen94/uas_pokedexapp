// lib/features/pokemon/widgets/pokemon_moves_table.dart

import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../models/pokemon_move_model.dart';
import '../widgets/pokemon_type_badge.dart';

class PokemonMovesTable extends StatefulWidget {
  final List<PokemonMove> moves;

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
      final matchesSearch =
          move.formattedName.toLowerCase().contains(_searchQuery);
      if (_selectedCategory == 'All') return matchesSearch;

      final category = move.damageClass.toLowerCase();
      return matchesSearch && _selectedCategory.toLowerCase() == category;
    }).toList();

    filteredMoves.sort((a, b) {
      switch (_sortBy) {
        case 'Power':
          return _ascending
              ? PokemonMove.compareByPower(a, b)
              : PokemonMove.compareByPower(b, a);
        case 'Accuracy':
          return _ascending
              ? PokemonMove.compareByAccuracy(a, b)
              : PokemonMove.compareByAccuracy(b, a);
        case 'PP':
          return _ascending
              ? PokemonMove.compareByPP(a, b)
              : PokemonMove.compareByPP(b, a);
        default:
          return _ascending
              ? PokemonMove.compareByName(a, b)
              : PokemonMove.compareByName(b, a);
      }
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

  Widget _buildMoveItem(PokemonMove move) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      title: Text(
        move.formattedName,
        style: AppTextStyles.titleMedium.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              PokemonTypeBadge.small(type: move.type),
              const SizedBox(width: 8),
              _buildCategoryIcon(move.damageClass),
              if (move.formattedEffect.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    move.formattedEffect,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (move.hasPower) _buildStatChip('Power', move.power.toString()),
          if (move.hasPower) const SizedBox(width: 8),
          if (move.hasAccuracy) _buildStatChip('Acc', '${move.accuracy}%'),
          if (move.hasAccuracy) const SizedBox(width: 8),
          _buildStatChip('PP', move.pp.toString()),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(String category) {
    IconData icon;
    Color color;

    switch (category.toLowerCase()) {
      case 'physical':
        icon = Icons.fitness_center;
        color = Colors.red[700]!;
        break;
      case 'special':
        icon = Icons.auto_awesome;
        color = Colors.blue[700]!;
        break;
      default:
        icon = Icons.change_circle;
        color = Colors.purple[700]!;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        icon,
        size: 16,
        color: color,
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
}
