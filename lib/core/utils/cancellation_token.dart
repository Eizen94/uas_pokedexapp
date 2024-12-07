// lib/core/utils/cancellation_token.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Advanced cancellation token with timeout and chaining capabilities.
/// Use this when you need complex cancellation scenarios like:
/// - Timeout based cancellation
/// - Multiple token chaining
/// - Future wrapping
/// - Cleanup registration
class AdvancedCancellationToken {
  // Internal state
  bool _isCancelled = false;
  final List<VoidCallback> _listeners = [];
  Timer? _timeout;

  // Public getters
  bool get isCancelled => _isCancelled;
  bool get hasListeners => _listeners.isNotEmpty;

  // Create token with optional timeout
  static AdvancedCancellationToken withTimeout(Duration timeout) {
    final token = AdvancedCancellationToken();
    token._setTimeout(timeout);
    return token;
  }

  // Create linked token
  static AdvancedCancellationToken fromMultiple(
      List<AdvancedCancellationToken> tokens) {
    final combinedToken = AdvancedCancellationToken();

    for (final token in tokens) {
      token.addListener(() {
        if (token.isCancelled) {
          combinedToken.cancel();
        }
      });
    }

    return combinedToken;
  }

  void _setTimeout(Duration timeout) {
    _timeout?.cancel();
    _timeout = Timer(timeout, () {
      if (!_isCancelled) {
        cancel(
            reason: 'Operation timed out after ${timeout.inSeconds} seconds');
      }
    });
  }

  // Cancel the operation
  void cancel({String? reason}) {
    if (_isCancelled) return;

    if (kDebugMode) {
      print('🚫 Operation cancelled${reason != null ? ': $reason' : ''}');
    }

    _isCancelled = true;
    _notifyListeners();
    _cleanup();
  }

  // Add cancellation listener
  void addListener(VoidCallback listener) {
    if (!_isCancelled) {
      _listeners.add(listener);
    } else {
      // If already cancelled, call listener immediately
      listener();
    }
  }

  // Remove cancellation listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  // Throw if cancelled
  void throwIfCancelled() {
    if (_isCancelled) {
      throw CancelledException();
    }
  }

  // Notify all listeners
  void _notifyListeners() {
    if (_listeners.isEmpty) return;

    // Create copy to avoid concurrent modification
    final listeners = List<VoidCallback>.from(_listeners);
    for (final listener in listeners) {
      try {
        listener();
      } catch (e) {
        if (kDebugMode) {
          print('Error in cancellation listener: $e');
        }
      }
    }
  }

  // Cleanup resources
  void _cleanup() {
    _timeout?.cancel();
    _timeout = null;
    _listeners.clear();
  }

  // Register callback to run on cancellation
  void onCancel(VoidCallback callback) {
    if (_isCancelled) {
      callback();
    } else {
      addListener(callback);
    }
  }

  // Wrap a Future to make it cancellable
  Future<T> wrapFuture<T>(Future<T> future) async {
    if (_isCancelled) throw CancelledException();

    final completer = Completer<T>();

    void onCancel() {
      if (!completer.isCompleted) {
        completer.completeError(CancelledException());
      }
    }

    addListener(onCancel);

    try {
      final result = await future;
      if (!completer.isCompleted && !_isCancelled) {
        completer.complete(result);
      }
    } catch (e) {
      if (!completer.isCompleted && !_isCancelled) {
        completer.completeError(e);
      }
    } finally {
      removeListener(onCancel);
    }

    return completer.future;
  }

  // Create a new linked token
  AdvancedCancellationToken chainWith(AdvancedCancellationToken other) {
    return fromMultiple([this, other]);
  }

  // Register cleanup callback
  void registerCleanup(VoidCallback cleanup) {
    onCancel(cleanup);
  }

  @override
  String toString() => 'AdvancedCancellationToken(isCancelled: $_isCancelled)';
}

class CancelledException implements Exception {
  final String? message;

  CancelledException([this.message]);

  @override
  String toString() => message ?? 'Operation was cancelled';
}

// Extension methods for Future
extension CancellableFutureExtension<T> on Future<T> {
  Future<T> withCancellation(AdvancedCancellationToken token) {
    return token.wrapFuture(this);
  }
}
