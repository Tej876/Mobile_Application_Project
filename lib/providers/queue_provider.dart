import 'dart:async';
import 'package:flutter/material.dart';
import '../models/department.dart';
import '../models/queue_token.dart';
import '../models/activity_log.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class QueueProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService();

  List<Department> _departments = [];
  List<Department> get departments => _departments;

  QueueToken? _currentPatientToken;
  QueueToken? get currentPatientToken => _currentPatientToken;

  List<QueueToken> _adminQueue = [];
  List<QueueToken> get adminQueue => _adminQueue;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Fetch all active departments with their current queue length from MongoDB backend
  Future<void> fetchDepartments() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.get('/api/departments');
      if (res is Map && res['departments'] is List) {
        _departments = (res['departments'] as List)
            .map((item) => Department.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (e) {
      debugPrint("⚠️ [QueueProvider] Error fetching departments: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Live stream of active queue length for a department (combining REST + Socket.IO updates)
  Stream<int> listenToDepartmentQueueLength(String departmentId) {
    late StreamController<int> controller;
    StreamSubscription? socketSub;

    controller = StreamController<int>(
      onListen: () async {
        // Initial fetch
        try {
          final res = await _api.get('/api/departments');
          if (res is Map && res['departments'] is List) {
            final deptJson = (res['departments'] as List).firstWhere(
              (d) => d['id'] == departmentId || d['_id'] == departmentId,
              orElse: () => null,
            );
            if (deptJson != null && !controller.isClosed) {
              final count = (deptJson['activeQueueLength'] as num?)?.toInt() ?? 0;
              controller.add(count);
            }
          }
        } catch (_) {}

        // Listen for live queue updates via Socket.IO
        socketSub = _socket.onQueueUpdated.listen((data) async {
          if (controller.isClosed) return;
          if (data['departmentId'] == departmentId) {
            try {
              final res = await _api.get('/api/departments');
              if (res is Map && res['departments'] is List && !controller.isClosed) {
                final deptJson = (res['departments'] as List).firstWhere(
                  (d) => d['id'] == departmentId || d['_id'] == departmentId,
                  orElse: () => null,
                );
                if (deptJson != null) {
                  final count = (deptJson['activeQueueLength'] as num?)?.toInt() ?? 0;
                  controller.add(count);
                }
              }
            } catch (_) {}
          }
        });
      },
      onCancel: () {
        socketSub?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Check if patient already has an active token across departments
  Future<Map<String, dynamic>?> findActivePatientToken(String patientId) async {
    try {
      final res = await _api.get('/api/queues/active');
      if (res is Map && res['hasActiveToken'] == true && res['token'] != null) {
        final token = QueueToken.fromJson(Map<String, dynamic>.from(res['token']));
        _currentPatientToken = token;
        return {
          'departmentId': token.departmentId,
          'departmentName': res['token']['departmentName'] ?? 'Department',
          'token': token,
        };
      }
    } catch (e) {
      debugPrint("⚠️ [QueueProvider] Error checking active token: $e");
    }
    return null;
  }

  /// Patient joins queue via POST /api/queues
  Future<QueueToken?> joinQueue(
    String departmentId,
    String patientId,
    String patientName,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      final res = await _api.post('/api/queues', {
        'departmentId': departmentId,
        'patientName': patientName,
      });

      if (res is Map && res['token'] != null) {
        final token = QueueToken.fromJson(Map<String, dynamic>.from(res['token']));
        _currentPatientToken = token;
        _socket.joinDepartment(departmentId);
        return token;
      }
      return null;
    } catch (e) {
      debugPrint("⚠️ [QueueProvider] Error joining queue: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Real-time stream for patient's own token in a department
  Stream<QueueToken?> listenToPatientToken(String departmentId, String patientId) {
    late StreamController<QueueToken?> controller;
    final List<StreamSubscription> subscriptions = [];

    controller = StreamController<QueueToken?>(
      onListen: () async {
        _socket.joinDepartment(departmentId);

        // Fetch current active token
        Future<void> refresh() async {
          if (controller.isClosed) return;
          try {
            final res = await _api.get('/api/queues/active');
            if (res is Map && !controller.isClosed) {
              if (res['hasActiveToken'] == true && res['token'] != null) {
                final token = QueueToken.fromJson(Map<String, dynamic>.from(res['token']));
                _currentPatientToken = token;
                controller.add(token);
              } else {
                // If not active, check history for most recent token (e.g. just served or cancelled)
                final histRes = await _api.get('/api/queues/history');
                if (histRes is Map && histRes['tokens'] is List && (histRes['tokens'] as List).isNotEmpty) {
                  final latestToken = QueueToken.fromJson(
                    Map<String, dynamic>.from((histRes['tokens'] as List).first),
                  );
                  _currentPatientToken = latestToken;
                  controller.add(latestToken);
                } else {
                  _currentPatientToken = null;
                  controller.add(null);
                }
              }
            }
          } catch (e) {
            debugPrint("⚠️ [QueueProvider] Token refresh error: $e");
          }
        }

        await refresh();

        // Listen for live socket events
        subscriptions.add(_socket.onQueueUpdated.listen((_) => refresh()));
        subscriptions.add(_socket.onTokenCreated.listen((_) => refresh()));
        subscriptions.add(_socket.onTokenCalled.listen((_) => refresh()));
        subscriptions.add(_socket.onTokenCancelled.listen((_) => refresh()));
        subscriptions.add(_socket.onTokenCompleted.listen((_) => refresh()));
      },
      onCancel: () {
        for (var sub in subscriptions) {
          sub.cancel();
        }
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Patient cancels token via PATCH /api/queues/:id/cancel
  Future<void> cancelToken(
    String departmentId,
    String tokenId,
    int tokenNumber,
    String patientName,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _api.patch('/api/queues/$tokenId/cancel');
      _currentPatientToken = null;
      notifyListeners();
    } catch (e) {
      debugPrint("⚠️ [QueueProvider] Error cancelling token: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update notification timestamp on server via PATCH /api/queues/:id/notified
  Future<void> updateNotifiedAt(String departmentId, String tokenId) async {
    try {
      await _api.patch('/api/queues/$tokenId/notified');
    } catch (e) {
      debugPrint("⚠️ [QueueProvider] Error updating notifiedAt: $e");
    }
  }

  /// ADMIN FLOW: Live queue stream for clinic admin dashboard
  Stream<List<QueueToken>> listenToAdminQueue(String departmentId) {
    late StreamController<List<QueueToken>> controller;
    final List<StreamSubscription> subscriptions = [];

    controller = StreamController<List<QueueToken>>(
      onListen: () async {
        _socket.joinDepartment(departmentId);

        Future<void> fetchQueue() async {
          if (controller.isClosed) return;
          try {
            final res = await _api.get('/api/admin/queues/$departmentId');
            if (res is Map && res['queue'] is List && !controller.isClosed) {
              _adminQueue = (res['queue'] as List)
                  .map((item) => QueueToken.fromJson(Map<String, dynamic>.from(item)))
                  .toList();
              controller.add(_adminQueue);
            } else if (!controller.isClosed) {
              _adminQueue = [];
              controller.add([]);
            }
          } catch (e) {
            debugPrint("⚠️ [QueueProvider] Admin queue fetch error: $e");
            if (!controller.isClosed) {
              controller.add(_adminQueue);
            }
          }
        }

        await fetchQueue();

        subscriptions.add(_socket.onQueueUpdated.listen((_) => fetchQueue()));
        subscriptions.add(_socket.onTokenCreated.listen((_) => fetchQueue()));
        subscriptions.add(_socket.onTokenCalled.listen((_) => fetchQueue()));
        subscriptions.add(_socket.onTokenCancelled.listen((_) => fetchQueue()));
        subscriptions.add(_socket.onTokenCompleted.listen((_) => fetchQueue()));
      },
      onCancel: () {
        for (var sub in subscriptions) {
          sub.cancel();
        }
        _socket.leaveDepartment(departmentId);
        controller.close();
      },
    );

    return controller.stream;
  }

  /// ADMIN FLOW: Live activity log stream
  Stream<List<ActivityLog>> listenToActivityLog(String departmentId) {
    late StreamController<List<ActivityLog>> controller;
    final List<StreamSubscription> subscriptions = [];

    controller = StreamController<List<ActivityLog>>(
      onListen: () async {
        Future<void> fetchLogs() async {
          if (controller.isClosed) return;
          try {
            final res = await _api.get('/api/admin/activity/$departmentId');
            if (res is Map && res['activityLogs'] is List && !controller.isClosed) {
              final logs = (res['activityLogs'] as List)
                  .map((item) => ActivityLog.fromJson(Map<String, dynamic>.from(item)))
                  .toList();
              controller.add(logs);
            } else if (!controller.isClosed) {
              controller.add([]);
            }
          } catch (e) {
            debugPrint("⚠️ [QueueProvider] Activity log fetch error: $e");
            if (!controller.isClosed) {
              controller.add([]);
            }
          }
        }

        await fetchLogs();

        subscriptions.add(_socket.onQueueUpdated.listen((_) => fetchLogs()));
        subscriptions.add(_socket.onTokenCompleted.listen((_) => fetchLogs()));
        subscriptions.add(_socket.onTokenCancelled.listen((_) => fetchLogs()));
      },
      onCancel: () {
        for (var sub in subscriptions) {
          sub.cancel();
        }
        controller.close();
      },
    );

    return controller.stream;
  }

  /// ADMIN FLOW: Call next patient in queue via PATCH /api/admin/queues/:deptId/call-next
  Future<void> callNextPatient(String departmentId) async {
    try {
      await _api.patch('/api/admin/queues/$departmentId/call-next');
      notifyListeners();
    } catch (e) {
      debugPrint("⚠️ [QueueProvider] Error calling next patient: $e");
      rethrow;
    }
  }

  /// ADMIN FLOW: Complete consultation (served or no-show)
  Future<void> markTokenDone(
    String departmentId,
    QueueToken token,
    bool isNoShow,
  ) async {
    try {
      final endpoint = isNoShow
          ? '/api/admin/queues/${token.id}/no-show'
          : '/api/admin/queues/${token.id}/complete';

      await _api.patch(endpoint);
      notifyListeners();
    } catch (e) {
      debugPrint("⚠️ [QueueProvider] Error marking token done: $e");
      rethrow;
    }
  }
}
