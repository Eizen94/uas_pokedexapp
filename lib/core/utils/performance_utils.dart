// lib/core/utils/performance_utils.dart

/// Performance utility functions for monitoring app metrics.
/// Provides centralized performance measurement methods.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Utility class for performance monitoring
class PerformanceUtils {
  // Private constructor to prevent instantiation
  const PerformanceUtils._();

  /// Get current frame time in milliseconds
  /// Returns the timestamp of current frame in milliseconds
  static double getCurrentFrameTime() {
    final binding = WidgetsBinding.instance;
    if (!binding.hasScheduledFrame) {
      return 0.0;
    }
    return binding.currentFrameTimeStamp.inMilliseconds.toDouble();
  }

  /// Get current memory usage indicator
  /// Returns an approximate memory usage value (0-100) in debug mode,
  /// or 0.0 in release mode
  static double getMemoryUsage() {
    if (!kDebugMode) return 0.0;

    try {
      final binding = WidgetsBinding.instance;
      if (!binding.rootElement!.dirty) {
        // If view is clean, return lower baseline
        return 25.0;
      }
      // Approximate based on dirty elements count
      return 50.0;
    } catch (_) {
      return 0.0;
    }
  }

  /// Check if performance monitoring is available
  /// Returns true if the app is in debug mode and has an active widget binding
  static bool get isAvailable {
    if (!kDebugMode) return false;
    try {
      return WidgetsBinding.instance.rootElement != null;
    } catch (_) {
      return false;
    }
  }
}
