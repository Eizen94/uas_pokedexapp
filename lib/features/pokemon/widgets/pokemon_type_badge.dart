// lib/features/pokemon/widgets/pokemon_type_badge.dart

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/utils/string_helper.dart';

/// Pokemon type badge component that displays the Pokemon's type
/// with proper styling and animations.
class PokemonTypeBadge extends StatelessWidget {
  final String type;
  final bool small;
  final VoidCallback? onTap;

  const PokemonTypeBadge({
    Key? key,
    required this.type,
    this.small = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final typeColor = AppColors.getTypeColor(type);
    final textColor = AppColors.getTextColorForBackground(typeColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(small ? 8 : 12),
        child: Ink(
          decoration: BoxDecoration(
            color: typeColor,
            borderRadius: BorderRadius.circular(small ? 8 : 12),
            boxShadow: [
              BoxShadow(
                color: typeColor.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: small ? 8 : 16,
              vertical: small ? 4 : 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Type Icon (if we have one)
                _buildTypeIcon(typeColor),
                if (!small) const SizedBox(width: 8),
                // Type Name
                Text(
                  StringHelper.formatTypeName(type),
                  style: (small
                          ? AppTextStyles.caption
                          : AppTextStyles.pokemonType)
                      .copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(Color typeColor) {
    // TODO: Add type icons when available
    return const SizedBox.shrink();
  }
}
