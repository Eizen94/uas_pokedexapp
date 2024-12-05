// lib/widgets/error_dialog.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uas_pokedexapp/core/constants/colors.dart';
import 'package:uas_pokedexapp/core/constants/text_styles.dart';
import 'package:uas_pokedexapp/core/utils/api_helper.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onRetry;
  final bool showRetryButton;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonText,
    this.onRetry,
    this.showRetryButton = true,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onRetry,
    bool showRetryButton = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        buttonText: buttonText,
        onRetry: onRetry,
        showRetryButton: showRetryButton,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          if (showRetryButton) const SizedBox(height: 24),
          if (showRetryButton)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onRetry?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      buttonText ?? 'Retry',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (!showRetryButton)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  buttonText ?? 'OK',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper method untuk menampilkan error dari ApiResponse
  static Future<void> showFromResponse(
    BuildContext context,
    ApiResponse response, {
    String? title,
    VoidCallback? onRetry,
  }) {
    String errorMessage;

    if (response.error is NoInternetException) {
      errorMessage =
          'No internet connection. Please check your connection and try again.';
    } else if (response.error is TimeoutException) {
      errorMessage = 'Request timed out. Please try again.';
    } else if (response.error is HttpException) {
      errorMessage = 'Failed to connect to server. Please try again later.';
    } else {
      errorMessage = response.message ?? 'An unexpected error occurred';
    }

    return show(
      context,
      title: title ?? 'Error',
      message: errorMessage,
      onRetry: onRetry,
      showRetryButton: onRetry != null,
    );
  }

  // Helper method untuk menampilkan error dari exception
  static Future<void> showException(
    BuildContext context,
    dynamic error, {
    String? title,
    VoidCallback? onRetry,
  }) {
    String errorMessage = 'An unexpected error occurred';

    if (error is NoInternetException) {
      errorMessage =
          'No internet connection. Please check your connection and try again.';
    } else if (error is TimeoutException) {
      errorMessage = 'Request timed out. Please try again.';
    } else if (error is HttpException) {
      errorMessage = 'Failed to connect to server. Please try again later.';
    } else {
      errorMessage = error.toString();
    }

    return show(
      context,
      title: title ?? 'Error',
      message: errorMessage,
      onRetry: onRetry,
      showRetryButton: onRetry != null,
    );
  }
}
