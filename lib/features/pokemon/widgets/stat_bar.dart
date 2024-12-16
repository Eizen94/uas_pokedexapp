// lib/widgets/stat_bar.dart

/// Stat bar widget to display Pokemon stats with animated progress bars.
/// Used in Pokemon detail view for stat visualization.
library;

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';

/// Pokemon stat bar widget
class StatBar extends StatefulWidget {
  /// Stat label (HP, Attack, etc.)
  final String label;

  /// Stat value (0-255)
  final int value;

  /// Maximum stat value (for percentage calculation)
  final double maxValue;

  /// Bar color
  final Color color;

  /// Animation duration
  final Duration animationDuration;

  /// Constructor
  const StatBar({
    required this.label,
    required this.value,
    this.maxValue = 255.0,
    required this.color,
    this.animationDuration = const Duration(milliseconds: 500),
    super.key,
  });

  @override
  State<StatBar> createState() => _StatBarState();
}

class _StatBarState extends State<StatBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0,
      end: widget.value / widget.maxValue,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void didUpdateWidget(StatBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value / widget.maxValue,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  widget.label,
                  style: AppTextStyles.statsLabel,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.value.toString(),
                style: AppTextStyles.statsValue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _animation.value,
                      backgroundColor: widget.color.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                      minHeight: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Helper class to create stat bars for specific stats
class PokemonStatBar extends StatelessWidget {
  /// Stat type
  final String statType;

  /// Stat value
  final int value;

  /// Constructor
  const PokemonStatBar({
    required this.statType,
    required this.value,
    super.key,
  });

  /// Get color based on stat type
  Color _getStatColor() {
    switch (statType.toLowerCase()) {
      case 'hp':
        return StatColors.hp;
      case 'attack':
        return StatColors.attack;
      case 'defense':
        return StatColors.defense;
      case 'special-attack':
        return StatColors.specialAttack;
      case 'special-defense':
        return StatColors.specialDefense;
      case 'speed':
        return StatColors.speed;
      default:
        return StatColors.total;
    }
  }

  /// Get formatted label
  String _getLabel() {
    switch (statType.toLowerCase()) {
      case 'hp':
        return 'HP';
      case 'attack':
        return 'Attack';
      case 'defense':
        return 'Defense';
      case 'special-attack':
        return 'Sp. Atk';
      case 'special-defense':
        return 'Sp. Def';
      case 'speed':
        return 'Speed';
      default:
        return 'Total';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatBar(
      label: _getLabel(),
      value: value,
      color: _getStatColor(),
    );
  }
}
