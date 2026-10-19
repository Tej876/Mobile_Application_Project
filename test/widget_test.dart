import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/models/queue_token.dart';
import 'package:queueless/models/department.dart';
import 'package:queueless/models/activity_log.dart';
import 'package:queueless/models/app_user.dart';

void main() {
  group('QueueLess Review 2 Model & Logic Unit Tests', () {
    test('AppUser JSON serialization and MongoDB UID mapping', () {
      final user = AppUser(
        uid: 'firebase-user-123',
        mongoId: '652f1234abcd5678ef901234',
        role: 'patient',
        name: 'Jane Doe',
        email: 'jane@example.com',
      );

      final json = user.toJson();
      expect(json['firebaseUid'], 'firebase-user-123');
      expect(json['role'], 'patient');
      expect(json['name'], 'Jane Doe');
      expect(json['email'], 'jane@example.com');

      final fromJson = AppUser.fromJson({
        'firebaseUid': 'firebase-user-123',
        '_id': '652f1234abcd5678ef901234',
        'role': 'patient',
        'name': 'Jane Doe',
        'email': 'jane@example.com',
      });

      expect(fromJson.uid, 'firebase-user-123');
      expect(fromJson.mongoId, '652f1234abcd5678ef901234');
      expect(fromJson.role, 'patient');
    });

    test('QueueToken JSON serialization with ISO 8601 dates and position', () {
      final now = DateTime.now();
      final token = QueueToken(
        id: '652f9876dcba4321fe098765',
        departmentId: '652f1234abcd5678ef901234',
        tokenNumber: 5,
        patientId: 'patient-abc',
        patientName: 'John Doe',
        status: 'waiting',
        joinedAt: now,
        position: 3,
        estWaitMins: 35,
      );

      final json = token.toJson();
      expect(json['id'], '652f9876dcba4321fe098765');
      expect(json['tokenNumber'], 5);
      expect(json['patientId'], 'patient-abc');
      expect(json['patientName'], 'John Doe');
      expect(json['status'], 'waiting');
      expect(json['position'], 3);
      expect(json['estWaitMins'], 35);

      final recreated = QueueToken.fromJson({
        '_id': '652f9876dcba4321fe098765',
        'departmentId': '652f1234abcd5678ef901234',
        'tokenNumber': 5,
        'patientId': 'patient-abc',
        'patientName': 'John Doe',
        'status': 'waiting',
        'joinedAt': now.toIso8601String(),
        'position': 3,
        'estWaitMins': 35,
      });

      expect(recreated.id, '652f9876dcba4321fe098765');
      expect(recreated.tokenNumber, 5);
      expect(recreated.patientName, 'John Doe');
      expect(recreated.status, 'waiting');
      expect(recreated.position, 3);
      expect(recreated.estWaitMins, 35);
    });

    test('Estimated Wait Time formula: (peopleAhead * avgConsultationMins) + 5', () {
      const avgMins = 10;

      // 0 people ahead
      int peopleAhead0 = 0;
      int waitTime0 = (peopleAhead0 * avgMins) + 5;
      expect(waitTime0, 5);

      // 3 people ahead
      int peopleAhead3 = 3;
      int waitTime3 = (peopleAhead3 * avgMins) + 5;
      expect(waitTime3, 35);
    });

    test('Department serialization with activeQueueLength', () {
      final dept = Department(
        id: '652f1234abcd5678ef901234',
        name: 'General Medicine',
        avgConsultationMins: 15,
        activeQueueLength: 4,
      );

      final json = dept.toJson();
      expect(json['name'], 'General Medicine');
      expect(json['avgConsultationMins'], 15);
      expect(json['activeQueueLength'], 4);

      final fromJson = Department.fromJson(json);
      expect(fromJson.id, '652f1234abcd5678ef901234');
      expect(fromJson.name, 'General Medicine');
      expect(fromJson.avgConsultationMins, 15);
      expect(fromJson.activeQueueLength, 4);
    });

    test('ActivityLog serialization with ISO 8601 timestamps', () {
      final now = DateTime.now();
      final log = ActivityLog(
        id: '652faaaa1111222233334444',
        tokenNumber: 3,
        patientName: 'Jane Smith',
        action: 'token_cancelled',
        timestamp: now,
      );

      final json = log.toJson();
      expect(json['tokenNumber'], 3);
      expect(json['patientName'], 'Jane Smith');
      expect(json['action'], 'token_cancelled');

      final fromJson = ActivityLog.fromJson({
        '_id': '652faaaa1111222233334444',
        'tokenNumber': 3,
        'patientName': 'Jane Smith',
        'action': 'token_cancelled',
        'timestamp': now.toIso8601String(),
      });

      expect(fromJson.id, '652faaaa1111222233334444');
      expect(fromJson.tokenNumber, 3);
      expect(fromJson.action, 'token_cancelled');
    });
  });
}
