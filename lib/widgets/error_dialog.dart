// lib/widgets/error_dialog.dart

/// Error dialog widget for displaying error messages.
/// Provides consistent error display across the app.
library;

import 'package:flutter/material.dart';

import '../core/constants/colors.dart';
import '../core/constants/text_styles.dart';

/// Error dialog widget
class ErrorDialog extends StatelessWidget {
  /// Error message to display
  final String message;

  /// Primary action callback
  final VoidCallback? onPrimaryAction;

  /// Primary action label
  final String primaryActionLabel;

  /// Secondary action callback
  final VoidCallback? onSecondaryAction;

  /// Secondary action label
  final String? secondaryActionLabel;

  /// Constructor
  const ErrorDialog({
    required this.message,
    this.onPrimaryAction,
    this.primaryActionLabel = 'OK',
    this.onSecondaryAction,
    this.secondaryActionLabel,
    super.key,
  });

  /// Show error dialog
  static Future<void> show({
    required BuildContext context,
    required String message,
    VoidCallback? onPrimaryAction,
    String primaryActionLabel = 'OK',
    VoidCallback? onSecondaryAction,
    String? secondaryActionLabel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorDialog(
        message: message,
        onPrimaryAction: onPrimaryAction ?? () => Navigator.pop(context),
        primaryActionLabel: primaryActionLabel,
        onSecondaryAction: onSecondaryAction,
        secondaryActionLabel: secondaryActionLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      icon: Icon(
        Icons.error_outline,
        color: AppColors.error,
        size: 48,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Error',
            style: AppTextStyles.heading3,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        if (secondaryActionLabel != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onSecondaryAction?.call();
            },
            child: Text(secondaryActionLabel!),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onPrimaryAction?.call();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryButton,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            primaryActionLabel,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
