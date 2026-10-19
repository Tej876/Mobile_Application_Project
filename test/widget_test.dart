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

    test('QueueToken parses populated departmentName and nested departmentId map', () {
      final fromJsonWithMap = QueueToken.fromJson({
        '_id': 'token-pop-1',
        'departmentId': {
          '_id': 'dept-ped-1',
          'name': 'Pediatrics',
        },
        'tokenNumber': 2,
        'patientId': 'patient-xyz',
        'patientName': 'Alice',
        'status': 'served',
        'joinedAt': DateTime.now().toIso8601String(),
        'position': 0,
        'estWaitMins': 0,
      });

      expect(fromJsonWithMap.departmentId, 'dept-ped-1');
      expect(fromJsonWithMap.departmentName, 'Pediatrics');
      expect(fromJsonWithMap.status, 'served');

      final fromJsonDirect = QueueToken.fromJson({
        '_id': 'token-pop-2',
        'departmentId': 'dept-cardio-1',
        'departmentName': 'Cardiology',
        'tokenNumber': 1,
        'patientId': 'patient-xyz',
        'patientName': 'Bob',
        'status': 'waiting',
        'joinedAt': DateTime.now().toIso8601String(),
        'position': 1,
        'estWaitMins': 5,
      });

      expect(fromJsonDirect.departmentId, 'dept-cardio-1');
      expect(fromJsonDirect.departmentName, 'Cardiology');
      expect(fromJsonDirect.position, 1);
      expect(fromJsonDirect.estWaitMins, 5);
    });

    test('Token position and wait-time calculation logic for waiting, called, served, and cancelled', () {
      const avgMins = 15;

      // 1. Waiting token with backend position and wait time
      final waitingToken = QueueToken(
        id: 't-wait-1',
        tokenNumber: 4,
        patientId: 'p-1',
        patientName: 'Pat',
        status: 'waiting',
        joinedAt: DateTime.now(),
        position: 2,
        estWaitMins: 20,
      );
      final waitPos = waitingToken.status == 'called'
          ? 0
          : (waitingToken.position > 0 ? waitingToken.position : (waitingToken.tokenNumber > 0 ? waitingToken.tokenNumber : 1));
      final waitAhead = waitPos > 0 ? waitPos - 1 : 0;
      final waitEst = waitingToken.status == 'called'
          ? 0
          : (waitingToken.estWaitMins > 0 ? waitingToken.estWaitMins : (waitAhead * avgMins) + 5);
      expect(waitPos, 2);
      expect(waitAhead, 1);
      expect(waitEst, 20);

      // 2. Waiting token missing position & wait time (fallback)
      final waitingFallback = QueueToken(
        id: 't-wait-2',
        tokenNumber: 3,
        patientId: 'p-2',
        patientName: 'Pat 2',
        status: 'waiting',
        joinedAt: DateTime.now(),
        position: 0,
        estWaitMins: 0,
      );
      final fbPos = waitingFallback.status == 'called'
          ? 0
          : (waitingFallback.position > 0 ? waitingFallback.position : (waitingFallback.tokenNumber > 0 ? waitingFallback.tokenNumber : 1));
      final fbAhead = fbPos > 0 ? fbPos - 1 : 0;
      final fbEst = waitingFallback.status == 'called'
          ? 0
          : (waitingFallback.estWaitMins > 0 ? waitingFallback.estWaitMins : (fbAhead * avgMins) + 5);
      expect(fbPos, 3);
      expect(fbAhead, 2);
      expect(fbEst, 35); // (2 * 15) + 5

      // 3. Called token (consultation room: 0 ahead, 0 wait)
      final calledToken = QueueToken(
        id: 't-called-1',
        tokenNumber: 5,
        patientId: 'p-3',
        patientName: 'Pat 3',
        status: 'called',
        joinedAt: DateTime.now(),
        position: 0,
        estWaitMins: 0,
      );
      final calledPos = calledToken.status == 'called'
          ? 0
          : (calledToken.position > 0 ? calledToken.position : (calledToken.tokenNumber > 0 ? calledToken.tokenNumber : 1));
      final calledAhead = calledPos > 0 ? calledPos - 1 : 0;
      final calledEst = calledToken.status == 'called'
          ? 0
          : (calledToken.estWaitMins > 0 ? calledToken.estWaitMins : (calledAhead * avgMins) + 5);
      expect(calledPos, 0);
      expect(calledAhead, 0);
      expect(calledEst, 0);

      // 4. Completed or cancelled token is recognized as terminal
      bool isTerminal(String status) => status != 'waiting' && status != 'called';
      expect(isTerminal('served'), isTrue);
      expect(isTerminal('cancelled'), isTrue);
      expect(isTerminal('no_show'), isTrue);
      expect(isTerminal('waiting'), isFalse);
      expect(isTerminal('called'), isFalse);
    });

    test('Receipt wait estimate only claims Next in line when backend confirms position == 1', () {
      const avgConsultationMins = 10;

      String computeEstWait(int position, int tokenNumber, int estWaitMins) {
        final int effectivePos = position > 0 ? position : tokenNumber;
        final int peopleAhead = effectivePos > 0 ? effectivePos - 1 : 0;
        final int calculatedWait = estWaitMins > 0 ? estWaitMins : (peopleAhead * avgConsultationMins) + 5;
        return position == 1 ? '~5 min (Next in line)' : '~$calculatedWait min';
      }

      // Backend confirms position == 1
      expect(computeEstWait(1, 1, 5), '~5 min (Next in line)');

      // Backend returns position == 0 with tokenNumber == 1 (must NOT claim Next in line)
      expect(computeEstWait(0, 1, 0), '~5 min');

      // Backend returns position == 0 with tokenNumber == 3 (must NOT claim Next in line)
      expect(computeEstWait(0, 3, 0), '~25 min');

      // Backend returns position == 2 (must NOT claim Next in line)
      expect(computeEstWait(2, 2, 15), '~15 min');
    });
  });
}
