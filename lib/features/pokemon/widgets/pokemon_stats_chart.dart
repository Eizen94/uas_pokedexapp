// lib/features/pokemon/widgets/pokemon_stats_chart.dart

import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../models/pokemon_detail_model.dart';

class PokemonStatsChart extends StatefulWidget {
  final PokemonDetailModel pokemon;
  final bool animate;

  const PokemonStatsChart({
    super.key,
    required this.pokemon,
    this.animate = true,
  });

  @override
  State<PokemonStatsChart> createState() => _PokemonStatsChartState();
}

class _PokemonStatsChartState extends State<PokemonStatsChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animations = widget.pokemon.statsList.map((stat) {
      return Tween<double>(
        begin: 0,
        end: stat.baseStat.toDouble(),
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            _animations.length * 0.1,
            1.0,
            curve: Curves.easeInOut,
          ),
        ),
      );
    }).toList();

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
            Text(
              'Base Stats',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(widget.pokemon.statsList.length, (index) {
              final stat = widget.pokemon.statsList[index];
              return AnimatedBuilder(
                animation: _animations[index],
                builder: (context, child) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                            Text(
                              stat.baseStat.toString().padLeft(3),
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _animations[index].value / 255,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _getStatColor(stat.baseStat),
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (index < widget.pokemon.statsList.length - 1)
                          const Divider(height: 16),
                      ],
                    ),
                  );
                },
              );
            }),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTotalStats(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalStats() {
    final total =
        widget.pokemon.statsList.map((s) => s.baseStat).reduce((a, b) => a + b);

    return Column(
      children: [
        Text(
          'Total',
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
    );
  }

  Color _getStatColor(int value) {
    if (value < 50) return AppColors.statHp.withOpacity(0.7);
    if (value < 100) return AppColors.statAttack.withOpacity(0.8);
    return AppColors.statSpAtk;
  }

  Color _getTotalColor(int total) {
    if (total < 300) return Colors.red[400]!;
    if (total < 400) return Colors.orange[400]!;
    if (total < 500) return Colors.green[400]!;
    return AppColors.primary;
  }
}
