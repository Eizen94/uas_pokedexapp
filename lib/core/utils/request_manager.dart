// lib/core/utils/request_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/subjects.dart';

/// Request priority levels
enum RequestPriority {
  /// High priority - immediate execution
  high,

  /// Normal priority - standard execution
  normal,

  /// Low priority - can be delayed
  low
}

/// Request status
enum RequestStatus {
  /// Request is pending
  pending,

  /// Request is currently executing
  executing,

  /// Request completed successfully
  completed,

  /// Request failed
  failed,

  /// Request was cancelled
  cancelled
}

/// Request entry for tracking
class RequestEntry {
  /// Unique request identifier
  final String id;

  /// Request priority
  final RequestPriority priority;

  /// Request type/endpoint
  final String type;

  /// Request parameters
  final Map<String, dynamic> parameters;

  /// Creation timestamp
  final DateTime timestamp;

  /// Current status
  RequestStatus status;

  /// Error message if failed
  String? errorMessage;

  RequestEntry({
    required this.id,
    required this.priority,
    required this.type,
    required this.parameters,
    required this.timestamp,
    this.status = RequestStatus.pending,
    this.errorMessage,
  });
}

/// Manages API request tracking and optimization
class RequestManager {
  static final RequestManager _instance = RequestManager._internal();

  /// Singleton instance
  factory RequestManager() => _instance;

  RequestManager._internal() {
    // Setup periodic cleanup
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkExpiredRequests(),
    );
  }

  final Map<String, RequestEntry> _activeRequests = {};
  final BehaviorSubject<List<RequestEntry>> _requestsController =
      BehaviorSubject<List<RequestEntry>>.seeded([]);
  Timer? _cleanupTimer;

  /// Maximum concurrent requests
  static const int _maxConcurrentRequests = 3;

  /// Request timeout duration
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Stream of active requests
  Stream<List<RequestEntry>> get requestsStream => _requestsController.stream;

  /// Current active requests
  List<RequestEntry> get activeRequests =>
      List.unmodifiable(_activeRequests.values.toList());

  /// Track new request
  String trackRequest({
    RequestPriority priority = RequestPriority.normal,
    required String type,
    Map<String, dynamic> parameters = const {},
  }) {
    final id = _generateRequestId();
    final entry = RequestEntry(
      id: id,
      priority: priority,
      type: type,
      parameters: parameters,
      timestamp: DateTime.now(),
    );

    _activeRequests[id] = entry;
    _updateRequests();

    return id;
  }

  /// Update request status
  void updateRequestStatus(String id, RequestStatus status, [String? error]) {
    final request = _activeRequests[id];
    if (request != null) {
      request.status = status;
      request.errorMessage = error;
      _updateRequests();

      if (status == RequestStatus.completed ||
          status == RequestStatus.failed ||
          status == RequestStatus.cancelled) {
        _cleanupRequest(id);
      }
    }
  }

  /// Cancel request
  void cancelRequest(String id) {
    updateRequestStatus(id, RequestStatus.cancelled);
  }

  /// Get request by ID
  RequestEntry? getRequest(String id) => _activeRequests[id];

  /// Get number of executing requests
  int get executingRequestsCount => _activeRequests.values
      .where((r) => r.status == RequestStatus.executing)
      .length;

  /// Check if new request can be executed
  bool canExecuteRequest() => executingRequestsCount < _maxConcurrentRequests;

  /// Check for expired requests
  void _checkExpiredRequests() {
    final now = DateTime.now();
    _activeRequests.forEach((id, request) {
      if (request.status == RequestStatus.executing &&
          now.difference(request.timestamp) > _requestTimeout) {
        updateRequestStatus(
            id, RequestStatus.failed, 'Request timeout exceeded');
      }
    });
  }

  /// Clean up completed/failed requests
  void _cleanupRequest(String id) {
    Timer(const Duration(seconds: 5), () {
      _activeRequests.remove(id);
      _updateRequests();
    });
  }

  /// Generate unique request ID
  String _generateRequestId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_activeRequests.length}';

  /// Update requests stream
  void _updateRequests() {
    if (!_requestsController.isClosed) {
      _requestsController.add(_activeRequests.values.toList());
    }
  }

  /// Clean up resources
  void dispose() {
    _cleanupTimer?.cancel();
    _activeRequests.clear();
    _requestsController.close();
  }
}

/// Extension methods for request management
extension RequestManagerExtension on RequestManager {
  /// Get requests by status
  List<RequestEntry> getRequestsByStatus(RequestStatus status) =>
      _activeRequests.values.where((r) => r.status == status).toList();

  /// Get requests by priority
  List<RequestEntry> getRequestsByPriority(RequestPriority priority) =>
      _activeRequests.values.where((r) => r.priority == priority).toList();

  /// Get failed requests
  List<RequestEntry> get failedRequests =>
      getRequestsByStatus(RequestStatus.failed);

  /// Get pending requests count
  int get pendingRequestsCount =>
      getRequestsByStatus(RequestStatus.pending).length;
}
