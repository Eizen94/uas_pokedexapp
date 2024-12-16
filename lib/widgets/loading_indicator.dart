// lib/widgets/loading_indicator.dart

/// Loading indicator widget for displaying loading states.
/// Provides consistent loading animation across the app.
library;

import 'package:flutter/material.dart';

import '../core/constants/colors.dart';

/// Loading indicator widget
class LoadingIndicator extends StatelessWidget {
  /// Loading message
  final String? message;

  /// Whether to show background overlay
  final bool showOverlay;

  /// Loading indicator color
  final Color? color;

  /// Loading indicator size
  final double size;

  /// Constructor
  const LoadingIndicator({
    this.message,
    this.showOverlay = true,
    this.color,
    this.size = 48.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final indicator = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? AppColors.primaryButton,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: TextStyle(
              color: color ?? AppColors.primaryText,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (!showOverlay) {
      return Center(child: indicator);
    }

    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(child: indicator),
      ),
    );
  }

  /// Show loading overlay
  static Future<void> show({
    required BuildContext context,
    String? message,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => LoadingIndicator(message: message),
    );
  }

  /// Hide loading overlay
  static void hide(BuildContext context) {
    Navigator.pop(context);
  }
}
