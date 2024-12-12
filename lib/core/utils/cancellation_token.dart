// lib/core/utils/cancellation_token.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'monitoring_manager.dart';
import 'request_manager.dart';

/// Enhanced cancellation token with proper resource management and error handling
class CancellationToken {
  // Internal state with proper type safety
  bool _isCancelled = false;
  bool _isDisposed = false;
  String? _cancelReason;
  DateTime? _cancelTime;

  // Resource management with proper cleanup
  final List<VoidCallback> _listeners = [];
  final List<Future<void>> _pendingOperations = [];
  final StreamController<CancellationEvent> _eventController =
      StreamController<CancellationEvent>.broadcast();
  Timer? _timeout;

  // Strongly typed getters
  bool get isCancelled => _isCancelled;
  bool get isDisposed => _isDisposed;
  String? get cancelReason => _cancelReason;
  DateTime? get cancelTime => _cancelTime;
  Stream<CancellationEvent> get events => _eventController.stream;
  bool get hasListeners => _listeners.isNotEmpty;

  /// Create token with timeout
  static CancellationToken withTimeout(Duration timeout) {
    final token = CancellationToken();
    token._setTimeout(timeout);
    return token;
  }

  /// Create linked token from multiple tokens
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

  /// Set timeout with proper cleanup
  void _setTimeout(Duration timeout) {
    _timeout?.cancel();
    _timeout = Timer(timeout, () {
      if (!_isCancelled && !_isDisposed) {
        cancel(
            reason: 'Operation timed out after ${timeout.inSeconds} seconds');
      }
    });
  }

  /// Add listener with proper error handling
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

  /// Remove listener safely
  void removeListener(VoidCallback listener) {
    _throwIfDisposed();
    _listeners.remove(listener);
  }

  /// Register cleanup action
  void registerCleanup(VoidCallback cleanup) {
    _throwIfDisposed();
    onCancel(cleanup);
  }

  /// Cancel operation with proper cleanup
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

  /// Handle listener errors properly
  void _handleListenerError(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      print('Error in cancellation listener: $error');
      print('Stack trace: $stackTrace');
    }
  }

  /// Clean up resources properly
  void _cleanup() {
    _timeout?.cancel();
    _timeout = null;
    _listeners.clear();
    _pendingOperations.clear();
  }

  /// Register cancellation callback
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

  /// Throw if cancelled with reason
  void throwIfCancelled() {
    if (_isCancelled) {
      throw CancelledException(_cancelReason);
    }
  }

  /// Make Future cancellable with proper resource tracking
  Future<T> wrapFuture<T>(Future<T> future) async {
    _throwIfDisposed();

    if (_isCancelled) {
      throw CancelledException(_cancelReason);
    }

    final completer = Completer<T>();
    _pendingOperations.add(future as Future<void>);

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

  /// Create linked token
  CancellationToken chainWith(CancellationToken other) {
    return fromMultiple([this, other]);
  }

  /// Proper resource disposal
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    cancel(reason: 'Token disposed');

    _timeout?.cancel();
    _listeners.clear();
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

/// Strongly typed cancellation event
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
