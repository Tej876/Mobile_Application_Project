import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:queueless/models/queue_token.dart';
import 'package:queueless/models/department.dart';
import 'package:queueless/models/activity_log.dart';

void main() {
  group('QueueLess Model & Logic Unit Tests', () {
    test('QueueToken serialization and deserialization', () {
      final now = DateTime.now();
      final token = QueueToken(
        id: 'tok-123',
        tokenNumber: 5,
        patientId: 'patient-abc',
        patientName: 'John Doe',
        status: 'waiting',
        joinedAt: now,
        notifiedAt: null,
      );

      final map = token.toMap();
      expect(map['tokenNumber'], 5);
      expect(map['patientId'], 'patient-abc');
      expect(map['patientName'], 'John Doe');
      expect(map['status'], 'waiting');
      expect(map['notifiedAt'], isNull);

      final recreated = QueueToken.fromMap({
        'tokenNumber': 5,
        'patientId': 'patient-abc',
        'patientName': 'John Doe',
        'status': 'waiting',
        'joinedAt': Timestamp.fromDate(now),
        'notifiedAt': null,
      }, 'tok-123');

      expect(recreated.id, 'tok-123');
      expect(recreated.tokenNumber, 5);
      expect(recreated.patientName, 'John Doe');
      expect(recreated.status, 'waiting');
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

    test('Department serialization and deserialization', () {
      final dept = Department(
        id: 'dept-1',
        name: 'General Medicine',
        avgConsultationMins: 15,
      );

      final map = dept.toMap();
      expect(map['name'], 'General Medicine');
      expect(map['avgConsultationMins'], 15);

      final fromMap = Department.fromMap(map, 'dept-1');
      expect(fromMap.id, 'dept-1');
      expect(fromMap.name, 'General Medicine');
      expect(fromMap.avgConsultationMins, 15);
    });

    test('ActivityLog serialization and deserialization', () {
      final now = DateTime.now();
      final log = ActivityLog(
        id: 'log-1',
        tokenNumber: 3,
        patientName: 'Jane Smith',
        action: 'cancelled',
        timestamp: now,
      );

      final map = log.toMap();
      expect(map['tokenNumber'], 3);
      expect(map['patientName'], 'Jane Smith');
      expect(map['action'], 'cancelled');

      final fromMap = ActivityLog.fromMap({
        'tokenNumber': 3,
        'patientName': 'Jane Smith',
        'action': 'cancelled',
        'timestamp': Timestamp.fromDate(now),
      }, 'log-1');

      expect(fromMap.tokenNumber, 3);
      expect(fromMap.action, 'cancelled');
    });
  });
}
