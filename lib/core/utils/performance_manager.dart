// lib/core/utils/performance_manager.dart

/// Performance manager to ensure smooth animations and efficient resource usage.
/// Handles frame timing, memory optimization, and battery efficiency.
library core.utils.performance_manager;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:rxdart/subjects.dart';

/// Manages application performance and animations
class PerformanceManager {
  static final PerformanceManager _instance = PerformanceManager._internal();
  factory PerformanceManager() => _instance;

  PerformanceManager._internal() {
    _initialize();
  }

  /// Frame timing tracker
  final Ticker? _ticker = SchedulerBinding.instance.createTicker((elapsed) {});
  
  /// Performance metrics stream controller
  final BehaviorSubject<PerformanceMetrics> _metricsController = 
      BehaviorSubject<PerformanceMetrics>();

  /// Last frame timestamp
  Duration _lastFrameTime = Duration.zero;
  
  /// Frame count for FPS calculation
  int _frameCount = 0;
  
  /// FPS calculation timer
  Timer? _fpsTimer;

  /// Stream of performance metrics
  Stream<PerformanceMetrics> get metricsStream => _metricsController.stream;

  /// Initialize performance monitoring
  void _initialize() {
    _ticker?.start();

    _fpsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _calculateMetrics(),
    );

    // Listen to frame callbacks for smooth animation tracking
    SchedulerBinding.instance.addPostFrameCallback(_onFrameEnd);
  }

  /// Calculate current FPS and other metrics
  void _calculateMetrics() {
    if (!_metricsController.isClosed) {
      final metrics = PerformanceMetrics(
        fps: _frameCount.toDouble(),
        isLowPerformance: _frameCount < 55, // Target is 60 FPS
        memoryUsage: _getMemoryUsage(),
      );

      _metricsController.add(metrics);
      _frameCount = 0;
    }
  }

  /// Frame end callback
  void _onFrameEnd(Duration timestamp) {
    if (_lastFrameTime != Duration.zero) {
      _frameCount++;
    }
    _lastFrameTime = timestamp;
    
    // Schedule next frame callback
    SchedulerBinding.instance.addPostFrameCallback(_onFrameEnd);
  }

  /// Get current memory usage
  double _getMemoryUsage() {
    // Only available in debug mode
    if (kDebugMode) {
      return WidgetsBinding.instance.performanceOverlay.value;
    }
    return 0.0;
  }

  /// Enable smooth animations for a specific widget
  Widget enableSmoothAnimations(Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: child,
    );
  }

  /// Check if animations should be throttled
  bool shouldThrottleAnimations() {
    final metrics = _metricsController.valueOrNull;
    if (metrics == null) return false;
    return metrics.isLowPerformance;
  }

  /// Apply performance optimizations to an image
  Widget optimizeImage({
    required ImageProvider imageProvider,
    required double width,
    required double height,
  }) {
    return Image(
      image: imageProvider,
      width: width,
      height: height,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: child,
        );
      },
    );
  }

  /// Dispose resources
  void dispose() {
    _ticker?.dispose();
    _fpsTimer?.cancel();
    _metricsController.close();
  }
}

/// Performance metrics data class
class PerformanceMetrics {
  /// Current frames per second
  final double fps;
  
  /// Whether device is in low performance state
  final bool isLowPerformance;
  
  /// Current memory usage
  final double memoryUsage;

  const PerformanceMetrics({
    required this.fps,
    required this.isLowPerformance,
    required this.memoryUsage,
  });

  /// Create metrics in high performance state
  factory PerformanceMetrics.high() => const PerformanceMetrics(
    fps: 60.0,
    isLowPerformance: false,
    memoryUsage: 0.0,
  );

  /// Create metrics in low performance state
  factory PerformanceMetrics.low() => const PerformanceMetrics(
    fps: 30.0,
    isLowPerformance: true,
    memoryUsage: 0.0,
  );

  @override
  String toString() => 
      'PerformanceMetrics(fps: $fps, isLowPerformance: $isLowPerformance, memoryUsage: $memoryUsage)';
}