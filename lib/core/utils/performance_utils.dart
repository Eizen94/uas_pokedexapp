// lib/core/utils/performance_utils.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Utility class for performance monitoring
class PerformanceUtils {
  // Private constructor to prevent instantiation
  const PerformanceUtils._();

  /// Get current frame time in milliseconds
  static double getCurrentFrameTime() {
    try {
      if (!SchedulerBinding.instance.hasScheduledFrame) {
        return 0.0;
      }
      final frameTimeStamp = SchedulerBinding.instance.currentFrameTimeStamp;
      if (frameTimeStamp == null) {
        return 0.0;
      }
      return frameTimeStamp.inMilliseconds.toDouble();
    } catch (e) {
      debugPrint('Error getting frame time: $e');
      return 0.0;
    }
  }

  /// Get current memory usage indicator
  static double getMemoryUsage() {
    if (!kDebugMode) return 0.0;

    try {
      final binding = WidgetsBinding.instance;
      final renderViews = binding.renderViews;
      if (renderViews.isEmpty) return 25.0;
      
      final rootView = renderViews.first;
      final usedLayerBytes = rootView.debugLayer?.debugSize ?? 0;
      final totalBytes = usedLayerBytes + (binding.pipelineOwner.debugOutstandingObjectCount ?? 0);
      
      // Return normalized value between 0-100
      return (totalBytes / (1024 * 1024) * 10).clamp(0.0, 100.0);
    } catch (e) {
      debugPrint('Error getting memory usage: $e');
      return 0.0; 
    }
  }

  /// Check if performance monitoring is available
  static bool get isAvailable {
    if (!kDebugMode) return false;
    try {
      return WidgetsBinding.instance.renderViews.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}