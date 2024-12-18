// lib/core/utils/rate_limiter.dart

/// Rate limiter utility to manage API request rates.
/// Prevents API abuse and ensures compliance with rate limits.
library;

import 'dart:async';
import 'dart:collection';
import 'package:rxdart/subjects.dart';

/// Rate limit exceeded exception
class RateLimitExceededException implements Exception {
  /// Error message
  final String message;

  /// Required wait time
  final Duration waitTime;

  /// Constructor
  const RateLimitExceededException({
    required this.message,
    required this.waitTime,
  });

  @override
  String toString() =>
      'RateLimitExceededException: $message (Wait: ${waitTime.inSeconds}s)';
}

/// Manages API request rate limiting
class RateLimiter {
  static final RateLimiter _instance = RateLimiter._internal();

  /// Maximum requests per time window
  static const int maxRequests = 100;

  /// Time window duration
  static const Duration timeWindow = Duration(minutes: 1);

  /// Singleton instance
  factory RateLimiter() => _instance;

  RateLimiter._internal();

  /// Queue for tracking request timestamps
  final Queue<DateTime> _requestTimestamps = Queue<DateTime>();

  /// Controller for rate limit status
  final BehaviorSubject<double> _usageController =
      BehaviorSubject<double>.seeded(0.0);

  /// Stream of rate limit usage (0.0 to 1.0)
  Stream<double> get usageStream => _usageController.stream;

  /// Current rate limit usage (0.0 to 1.0)
  double get currentUsage => _usageController.value;

  /// Check if request can be made
  Future<void> checkRateLimit() async {
    _cleanOldTimestamps();

    if (_requestTimestamps.length >= RateLimiter.maxRequests) {
      final oldestTimestamp = _requestTimestamps.first;
      final windowEnd = oldestTimestamp.add(RateLimiter.timeWindow);
      final now = DateTime.now();

      if (now.isBefore(windowEnd)) {
        final waitTime = windowEnd.difference(now);
        throw RateLimitExceededException(
          message: 'Rate limit exceeded. Please wait.',
          waitTime: waitTime,
        );
      }
    }

    _requestTimestamps.addLast(DateTime.now());
    _updateUsage();
  }

  /// Remove timestamps outside current window
  void _cleanOldTimestamps() {
    final now = DateTime.now();
    final cutoff = now.subtract(RateLimiter.timeWindow);

    while (_requestTimestamps.isNotEmpty &&
        _requestTimestamps.first.isBefore(cutoff)) {
      _requestTimestamps.removeFirst();
    }

    _updateUsage();
  }

  /// Update rate limit usage
  void _updateUsage() {
    if (!_usageController.isClosed) {
      _usageController.add(_requestTimestamps.length / RateLimiter.maxRequests);
    }
  }

  /// Get remaining requests in current window
  int get remainingRequests =>
      RateLimiter.maxRequests - _requestTimestamps.length;

  /// Get time until rate limit reset
  Duration get timeUntilReset {
    if (_requestTimestamps.isEmpty) return Duration.zero;

    final oldestTimestamp = _requestTimestamps.first;
    final resetTime = oldestTimestamp.add(RateLimiter.timeWindow);
    final now = DateTime.now();

    return now.isBefore(resetTime) ? resetTime.difference(now) : Duration.zero;
  }

  /// Reset rate limiter
  void reset() {
    _requestTimestamps.clear();
    _updateUsage();
  }

  /// Dispose resources
  void dispose() {
    _usageController.close();
  }
}

/// Extension methods for rate limiting
extension RateLimiterExtension on RateLimiter {
  /// Whether rate limit is currently exceeded
  bool get isLimited => _requestTimestamps.length >= RateLimiter.maxRequests;

  /// Percentage of rate limit used (0-100)
  double get usagePercentage => currentUsage * 100;

  /// Format remaining time as string
  String get remainingTimeFormatted {
    final duration = timeUntilReset;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
