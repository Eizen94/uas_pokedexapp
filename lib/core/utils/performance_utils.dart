// lib/core/utils/performance_utils.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Utility class for performance monitoring
class PerformanceUtils {
  const PerformanceUtils._();

  /// Get current frame time in milliseconds
  static double getCurrentFrameTime() {
    try {
      if (!SchedulerBinding.instance.hasScheduledFrame) {
        return 0.0;
      }
      
      // Safe access to frameTimeStamp
      final binding = SchedulerBinding.instance;
      if (!binding.framesEnabled) {
        return 0.0;
      }
      
      return binding.currentFrameTimeStamp.inMilliseconds.toDouble();
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
      if (!binding.renderViews.isNotEmpty) return 25.0;
      
      // Simple memory estimation based on elements
      final elementCount = binding.buildOwner?.debugElementCount ?? 0;
      final estimatedMemory = elementCount * 1024; // Rough estimation
      
      // Return normalized value between 0-100
      return (estimatedMemory / (1024 * 1024) * 10).clamp(0.0, 100.0);
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