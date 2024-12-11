// lib/core/utils/cancellation_token.dart

// Dart imports
import 'dart:async';

// Package imports
import 'package:flutter/foundation.dart';

// Local imports
import 'request_manager.dart';
import 'monitoring_manager.dart';

/// Enhanced cancellation token with timeout and chaining capabilities.
/// Provides proper resource management and error handling.
class CancellationToken {
  // Internal state
  bool _isCancelled = false;
  bool _isDisposed = false;
  String? _cancelReason;
  DateTime? _cancelTime;

  // Resource management
  final List<VoidCallback> _listeners = [];
  final List<Future> _pendingOperations = [];
  final StreamController<CancellationEvent> _eventController =
      StreamController<CancellationEvent>.broadcast();
  Timer? _timeout;

  // Getters
  bool get isCancelled => _isCancelled;
  bool get isDisposed => _isDisposed;
  String? get cancelReason => _cancelReason;
  DateTime? get cancelTime => _cancelTime;
  Stream<CancellationEvent> get events => _eventController.stream;
  bool get hasListeners => _listeners.isNotEmpty;

  /// Create a token with timeout
  static CancellationToken withTimeout(Duration timeout) {
    final token = CancellationToken();
    token._setTimeout(timeout);
    return token;
  }

  /// Create a linked token from multiple tokens
  static CancellationToken fromMultiple(List<CancellationToken> tokens) {
    assert(tokens.isNotEmpty, 'Token list cannot be empty');

    final combinedToken = CancellationToken();

    for (final token in tokens) {
      token.addListener(() {
        if (token.isCancelled) {
          combinedToken.cancel(
            reason: 'Cancelled by linked token: ${token.cancelReason}',
          );
        }
      });
    }

    return combinedToken;
  }

  /// Set timeout for cancellation
  void _setTimeout(Duration timeout) {
    _timeout?.cancel();
    _timeout = Timer(timeout, () {
      if (!_isCancelled && !_isDisposed) {
        cancel(
            reason: 'Operation timed out after ${timeout.inSeconds} seconds');
      }
    });
  }

  /// Add cancellation listener with error handling
  void addListener(VoidCallback listener) {
    _throwIfDisposed();

    if (_isCancelled) {
      try {
        listener();
      } catch (e, stackTrace) {
        _handleListenerError(e, stackTrace);
      }
    } else {
      _listeners.add(listener);
    }
  }

  /// Remove cancellation listener
  void removeListener(VoidCallback listener) {
    _throwIfDisposed();
    _listeners.remove(listener);
  }

  /// Register cleanup action
  void registerCleanup(VoidCallback cleanup) {
    _throwIfDisposed();
    onCancel(cleanup);
  }

  /// Cancel the operation with proper cleanup
  void cancel({String? reason}) {
    if (_isCancelled || _isDisposed) return;

    _isCancelled = true;
    _cancelReason = reason;
    _cancelTime = DateTime.now();

    if (!_eventController.isClosed) {
      _eventController.add(CancellationEvent(reason: reason));
    }

    _notifyListeners();
    _cleanup();

    if (kDebugMode) {
      print('🚫 Operation cancelled${reason != null ? ': $reason' : ''}');
    }
  }

  /// Notify listeners with error handling
  void _notifyListeners() {
    if (_listeners.isEmpty || _isDisposed) return;

    final listeners = List<VoidCallback>.from(_listeners);
    _listeners.clear();

    for (final listener in listeners) {
      try {
        listener();
      } catch (e, stackTrace) {
        _handleListenerError(e, stackTrace);
      }
    }
  }

  /// Handle listener errors
  void _handleListenerError(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      print('Error in cancellation listener: $error');
      print('Stack trace: $stackTrace');
    }
  }

  /// Clean up resources
  void _cleanup() {
    _timeout?.cancel();
    _timeout = null;
    _listeners.clear();
  }

  /// Register callback for cancellation
  void onCancel(VoidCallback callback) {
    _throwIfDisposed();

    if (_isCancelled) {
      try {
        callback();
      } catch (e, stackTrace) {
        _handleListenerError(e, stackTrace);
      }
    } else {
      addListener(callback);
    }
  }

  /// Throw if cancelled
  void throwIfCancelled() {
    if (_isCancelled) {
      throw CancelledException(_cancelReason);
    }
  }

  /// Make a Future cancellable
  Future<T> wrapFuture<T>(Future<T> future) async {
    _throwIfDisposed();

    if (_isCancelled) {
      throw CancelledException(_cancelReason);
    }

    final completer = Completer<T>();
    _pendingOperations.add(future);

    void onCancel() {
      if (!completer.isCompleted) {
        completer.completeError(CancelledException(_cancelReason));
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
      _pendingOperations.remove(future);
    }

    return completer.future;
  }

  /// Create a linked token with another token
  CancellationToken chainWith(CancellationToken other) {
    return fromMultiple([this, other]);
  }

  /// Resource disposal
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    cancel(reason: 'Token disposed');

    _timeout?.cancel();
    _listeners.clear();
    _pendingOperations.clear();

    await _eventController.close();

    if (kDebugMode) {
      print('🧹 CancellationToken disposed');
    }
  }

  /// Check if disposed
  void _throwIfDisposed() {
    if (_isDisposed) {
      throw StateError('CancellationToken has been disposed');
    }
  }

  @override
  String toString() => 'CancellationToken('
      'cancelled: $_isCancelled, '
      'disposed: $_isDisposed, '
      'reason: $_cancelReason)';
}

/// Cancellation event for monitoring
class CancellationEvent {
  final String? reason;
  final DateTime timestamp;

  CancellationEvent({
    this.reason,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'CancellationEvent(reason: $reason, timestamp: $timestamp)';
}

/// Custom cancellation exception
class CancelledException implements Exception {
  final String? message;

  const CancelledException([this.message]);

  @override
  String toString() =>
      'CancelledException: ${message ?? 'Operation was cancelled'}';
}

/// Extension for making Futures cancellable
extension CancellableFutureExtension<T> on Future<T> {
  Future<T> withCancellation(CancellationToken token) {
    return token.wrapFuture(this);
  }
}
