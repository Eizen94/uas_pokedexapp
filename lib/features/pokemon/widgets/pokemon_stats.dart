// lib/features/pokemon/widgets/pokemon_stats.dart

import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../models/pokemon_detail_model.dart';

class PokemonStats extends StatelessWidget {
  final PokemonDetailModel pokemon;
  final bool showChart;
  final bool showMinMax;

  const PokemonStats({
    super.key,
    required this.pokemon,
    this.showChart = true,
    this.showMinMax = false,
  });

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Statistik Dasar',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (showMinMax)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Level 50',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Level 100',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...pokemon.statsList.map((stat) => _buildStatRow(stat)),
            const Divider(height: 24),
            _buildTotalStats(),
            if (showMinMax) ...[
              const SizedBox(height: 16),
              _buildStatRangeInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(Stat stat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              stat.getFormattedName(),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              stat.baseStat.toString(),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: stat.baseStat / 255,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getStatColor(stat.baseStat),
                    ),
                    minHeight: 8,
                  ),
                ),
                if (showMinMax) ...[
                  const SizedBox(height: 4),
                  _buildMinMaxValues(stat),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinMaxValues(Stat stat) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _calculateMinValue(stat.baseStat).toString(),
          style: AppTextStyles.caption.copyWith(
            color: Colors.grey[600],
          ),
        ),
        Text(
          _calculateMaxValue(stat.baseStat).toString(),
          style: AppTextStyles.caption.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalStats() {
    final total =
        pokemon.statsList.map((s) => s.baseStat).reduce((a, b) => a + b);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            Text(
              'Total Base Stats',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _getTotalColor(total),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                total.toString(),
                style: AppTextStyles.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatRangeInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Catatan:',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• Nilai minimum diasumsikan dengan IV 0 dan nature negatif',
            style: AppTextStyles.caption,
          ),
          Text(
            '• Nilai maksimum diasumsikan dengan IV 31 dan nature positif',
            style: AppTextStyles.caption,
          ),
          Text(
            '• HP tidak dipengaruhi oleh nature',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Color _getStatColor(int value) {
    if (value < 50) return AppColors.error;
    if (value < 70) return AppColors.warning;
    if (value < 90) return Colors.orange;
    if (value < 110) return Colors.green;
    if (value < 130) return AppColors.primary;
    return AppColors.success;
  }

  Color _getTotalColor(int total) {
    if (total < 300) return AppColors.error;
    if (total < 400) return AppColors.warning;
    if (total < 500) return Colors.orange;
    if (total < 600) return AppColors.success;
    return AppColors.primary;
  }

  int _calculateMinValue(int baseStat) {
    if (baseStat == pokemon.statsList[0].baseStat) {
      // HP calculation
      return ((2 * baseStat) + 110).floor();
    }
    // Other stats with negative nature
    return ((2 * baseStat) + 5).floor();
  }

  int _calculateMaxValue(int baseStat) {
    if (baseStat == pokemon.statsList[0].baseStat) {
      // HP calculation
      return ((2 * baseStat + 31 + 252 / 4) + 110).floor();
    }
    // Other stats with positive nature
    return (((2 * baseStat + 31 + 252 / 4) + 5) * 1.1).floor();
  }
}
