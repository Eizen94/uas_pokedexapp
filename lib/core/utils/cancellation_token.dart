// lib/core/utils/cancellation_token.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Advanced cancellation token with timeout and chaining capabilities
class CancellationToken {
  // Internal state
  bool _isCancelled = false;
  final List<VoidCallback> _listeners = [];
  Timer? _timeout;
  bool _isDisposed = false;

  // Public getters
  bool get isCancelled => _isCancelled;
  bool get hasListeners => _listeners.isNotEmpty;

  /// Create token with timeout
  static CancellationToken withTimeout(Duration timeout) {
    final token = CancellationToken();
    token._setTimeout(timeout);
    return token;
  }

  /// Create linked token
  static CancellationToken fromMultiple(List<CancellationToken> tokens) {
    final combinedToken = CancellationToken();

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

  /// Cancel the operation with proper cleanup
  void cancel({String? reason}) {
    if (_isCancelled || _isDisposed) return;

    if (kDebugMode) {
      print('🚫 Operation cancelled${reason != null ? ': $reason' : ''}');
    }

    _isCancelled = true;
    _notifyListeners();
    _cleanup();
  }

  /// Add cancellation listener with safety checks
  void addListener(VoidCallback listener) {
    if (_isDisposed) return;

    if (!_isCancelled) {
      _listeners.add(listener);
    } else {
      // If already cancelled, call listener immediately
      listener();
    }
  }

  /// Remove cancellation listener
  void removeListener(VoidCallback listener) {
    if (_isDisposed) return;
    _listeners.remove(listener);
  }

  /// Throw if cancelled
  void throwIfCancelled() {
    if (_isCancelled) {
      throw CancelledException();
    }
  }

  /// Notify all listeners with safety
  void _notifyListeners() {
    if (_listeners.isEmpty || _isDisposed) return;

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

  /// Cleanup resources
  void _cleanup() {
    _timeout?.cancel();
    _timeout = null;
    _listeners.clear();
  }

  /// Register callback to run on cancellation
  void onCancel(VoidCallback callback) {
    if (_isDisposed) return;

    if (_isCancelled) {
      callback();
    } else {
      addListener(callback);
    }
  }

  /// Wrap a Future to make it cancellable
  Future<T> wrapFuture<T>(Future<T> future) async {
    if (_isCancelled) throw CancelledException();
    if (_isDisposed) throw StateError('Token has been disposed');

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

  /// Create a new linked token
  CancellationToken chainWith(CancellationToken other) {
    return fromMultiple([this, other]);
  }

  /// Register cleanup callback
  void registerCleanup(VoidCallback cleanup) {
    onCancel(cleanup);
  }

  /// Resource disposal
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _cleanup();
  }

  @override
  String toString() =>
      'CancellationToken(isCancelled: $_isCancelled, isDisposed: $_isDisposed)';
}

/// Cancellation exception
class CancelledException implements Exception {
  final String? message;

  const CancelledException([this.message]);

  @override
  String toString() => message ?? 'Operation was cancelled';
}

/// Extension methods for Future
extension CancellableFutureExtension<T> on Future<T> {
  Future<T> withCancellation(CancellationToken token) {
    return token.wrapFuture(this);
  }
}
