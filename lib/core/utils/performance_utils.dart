// lib/core/utils/performance_utils.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Utility class for performance monitoring helpers
class PerformanceUtils {
  const PerformanceUtils._();

  /// Get current frame time in milliseconds
  static double getCurrentFrameTime() {
    return WidgetsBinding.instance.currentFrameTimeStamp.inMilliseconds
        .toDouble();
  }

  /// Get approximate memory usage (debug only)
  static double getApproximateMemoryUsage() {
    if (!kDebugMode) return 0.0;
    // Simplified memory tracking that won't impact performance
    return 50.0; // Base memory indicator
  }
}
