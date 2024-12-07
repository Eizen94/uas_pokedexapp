// lib/features/pokemon/widgets/pokemon_stats_radar.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../models/pokemon_detail_model.dart';

class PokemonStatsRadar extends StatelessWidget {
  final List<Stat> stats;
  final bool animate;
  final Duration animationDuration;

  const PokemonStatsRadar({
    super.key,
    required this.stats,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 1500),
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
            Text(
              'Base Stats',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1,
              child: animate
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: animationDuration,
                      builder: (context, value, child) {
                        return CustomPaint(
                          painter: _RadarChartPainter(
                            stats: stats,
                            progress: value,
                          ),
                        );
                      },
                    )
                  : CustomPaint(
                      painter: _RadarChartPainter(
                        stats: stats,
                        progress: 1,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: stats.map((stat) {
        final color = _getStatColor(stat.baseStat);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${stat.getFormattedName()}: ${stat.baseStat}',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Color _getStatColor(int value) {
    if (value < 50) return AppColors.statHp;
    if (value < 70) return AppColors.statAttack;
    if (value < 90) return AppColors.statDefense;
    if (value < 110) return AppColors.statSpAtk;
    if (value < 130) return AppColors.statSpDef;
    return AppColors.statSpeed;
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<Stat> stats;
  final double progress;
  static const double maxValue = 255.0;

  _RadarChartPainter({
    required this.stats,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Draw background grid
    _drawGrid(canvas, center, radius);

    // Draw stat values
    _drawStats(canvas, center, radius);

    // Draw labels
    _drawLabels(canvas, center, radius);
  }

  void _drawGrid(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    const levels = 5;

    for (var i = 1; i <= levels; i++) {
      final currentRadius = radius * i / levels;
      path.reset();

      for (var j = 0; j < stats.length; j++) {
        final angle = 2 * math.pi * (j / stats.length) - math.pi / 2;
        final point = Offset(
          center.dx + currentRadius * math.cos(angle),
          center.dy + currentRadius * math.sin(angle),
        );

        if (j == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    // Draw axis lines
    for (var i = 0; i < stats.length; i++) {
      final angle = 2 * math.pi * (i / stats.length) - math.pi / 2;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, point, paint);
    }
  }

  void _drawStats(Canvas canvas, Offset center, double radius) {
    final path = Path();
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < stats.length; i++) {
      final angle = 2 * math.pi * (i / stats.length) - math.pi / 2;
      final value = (stats[i].baseStat / maxValue) * progress;
      final point = Offset(
        center.dx + radius * value * math.cos(angle),
        center.dy + radius * value * math.sin(angle),
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    path.close();
    canvas.drawPath(path, paint);

    // Draw outline
    paint
      ..style = PaintingStyle.stroke
      ..color = AppColors.primary
      ..strokeWidth = 2.0;
    canvas.drawPath(path, paint);
  }

  void _drawLabels(Canvas canvas, Offset center, double radius) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i < stats.length; i++) {
      final angle = 2 * math.pi * (i / stats.length) - math.pi / 2;
      final labelRadius = radius + 20;
      final point = Offset(
        center.dx + labelRadius * math.cos(angle),
        center.dy + labelRadius * math.sin(angle),
      );

      textPainter.text = TextSpan(
        text: stats[i].getFormattedName(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondaryLight,
        ),
      );
      textPainter.layout();

      final textOffset = Offset(
        point.dx - textPainter.width / 2,
        point.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Example usage:
///```dart
/// PokemonStatsRadar(
///   stats: pokemon.statsList,
///   animate: true,
/// )
///```