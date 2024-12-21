// lib/core/utils/performance_utils.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Utility class for performance monitoring and metrics collection.
/// Provides safe access to performance-related data in debug mode.
class PerformanceUtils {
  // Private constructor to prevent instantiation
  const PerformanceUtils._();

  /// Get current frame time in milliseconds with safety checks.
  /// Returns 0.0 if unable to get frame time safely.
  static double getCurrentFrameTime() {
    if (!kDebugMode) return 0.0;

    try {
      final binding = SchedulerBinding.instance;
      if (!binding.hasScheduledFrame || !binding.framesEnabled) {
        return 0.0;
      }

      // Get frame timestamp safely
      Duration? duration = binding.schedulerPhase == SchedulerPhase.idle
          ? binding.currentFrameTimeStamp
          : null;

      return duration?.inMilliseconds.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('Error getting frame time: $e');
      return 0.0;
    }
  }

  /// Get current memory usage indicator (0-100).
  /// Uses active render objects count as a proxy for memory usage.
  static double getMemoryUsage() {
    if (!kDebugMode) return 0.0;

    try {
      final binding = WidgetsBinding.instance;
      final renderViews = binding.renderViews;

      if (renderViews.isEmpty) {
        return 25.0; // Baseline when no views
      }

      // Count active render objects
      int totalRenderObjects = 0;
      for (var view in renderViews) {
        void countRenderObjects(RenderObject object) {
          totalRenderObjects++;
          object.visitChildren(countRenderObjects);
        }

        countRenderObjects(view);
      }

      // Calculate memory estimation
      const objectWeight = 1.5; // KB per render object estimate
      const baselineMemory = 50.0 * 1024; // 50MB baseline

      // Convert to memory estimate
      final estimatedMemoryKB =
          baselineMemory + (totalRenderObjects * objectWeight);

      // Convert to 0-100 scale
      const maxExpectedMemoryKB = 200.0 * 1024; // 200MB threshold
      return (estimatedMemoryKB / maxExpectedMemoryKB * 100.0)
          .clamp(0.0, 100.0);
    } catch (e) {
      debugPrint('Error calculating memory usage: $e');
      return 0.0;
    }
  }

  /// Check if performance monitoring is available.
  /// Only available in debug mode with an active widget tree.
  static bool get isAvailable {
    if (!kDebugMode) return false;

    try {
      final binding = WidgetsBinding.instance;
      return binding.renderViews.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking performance monitoring availability: $e');
      return false;
    }
  }
}
