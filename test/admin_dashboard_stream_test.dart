import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:queueless/models/activity_log.dart';
import 'package:queueless/models/department.dart';
import 'package:queueless/models/queue_token.dart';
import 'package:queueless/providers/auth_provider.dart';
import 'package:queueless/providers/queue_provider.dart';
import 'package:queueless/screens/admin/dashboard_screen.dart';

class _FakeQueueProvider extends ChangeNotifier implements QueueProvider {
  final List<StreamController<List<QueueToken>>> queueControllers = [];
  final List<StreamController<List<ActivityLog>>> activityControllers = [];

  @override
  List<Department> get departments => [
    Department(
      id: 'department-1',
      name: 'General Medicine',
      avgConsultationMins: 15,
    ),
  ];

  @override
  bool get isLoading => false;

  @override
  Future<void> fetchDepartments() async {}

  @override
  Stream<List<QueueToken>> listenToAdminQueue(String departmentId) {
    late final StreamController<List<QueueToken>> controller;
    controller = StreamController<List<QueueToken>>(
      onListen: () => controller.add(const []),
    );
    queueControllers.add(controller);
    return controller.stream;
  }

  @override
  Stream<List<ActivityLog>> listenToActivityLog(String departmentId) {
    late final StreamController<List<ActivityLog>> controller;
    controller = StreamController<List<ActivityLog>>(
      onListen: () => controller.add(const []),
    );
    activityControllers.add(controller);
    return controller.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('admin dashboard creates fresh streams when switching tabs', (
    tester,
  ) async {
    final queue = _FakeQueueProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<QueueProvider>.value(value: queue),
          ChangeNotifierProvider<AuthProvider>.value(
            value: _FakeAuthProvider(),
          ),
        ],
        child: const MaterialApp(home: AdminDashboardScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(queue.queueControllers, hasLength(1));
    expect(queue.activityControllers, hasLength(1));

    await tester.tap(find.text('Activity Audit Log'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(queue.activityControllers, hasLength(2));

    await tester.tap(find.text('Active Queue'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(queue.queueControllers, hasLength(2));

    await tester.tap(find.text('Activity Audit Log'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(queue.activityControllers, hasLength(3));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
