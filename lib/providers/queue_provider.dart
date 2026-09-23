import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/department.dart';
import '../models/queue_token.dart';
import '../models/activity_log.dart';

class QueueProvider extends ChangeNotifier {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  List<Department> _departments = [];
  List<Department> get departments => _departments;

  QueueToken? _currentPatientToken;
  QueueToken? get currentPatientToken => _currentPatientToken;

  List<QueueToken> _adminQueue = [];
  List<QueueToken> get adminQueue => _adminQueue;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchDepartments() async {
    _isLoading = true;
    notifyListeners();

    try {
      var snapshot = await _firestore.collection('departments').get();

      // Seed common departments if empty
      if (snapshot.docs.isEmpty) {
        final standardDepts = [
          {'name': 'General Medicine', 'avgConsultationMins': 15},
          {'name': 'Cardiology', 'avgConsultationMins': 20},
          {'name': 'Orthopedics', 'avgConsultationMins': 25},
          {'name': 'Pediatrics', 'avgConsultationMins': 15},
          {'name': 'Dermatology', 'avgConsultationMins': 10},
          {'name': 'Neurology', 'avgConsultationMins': 30},
        ];

        final batch = _firestore.batch();
        for (var dept in standardDepts) {
          final doc = _firestore.collection('departments').doc();
          batch.set(doc, dept);
        }
        await batch.commit();
        snapshot = await _firestore.collection('departments').get();
      }

      _departments = snapshot.docs
          .map((doc) => Department.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint("Error fetching departments: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Stream active queue length for department selection screen
  Stream<int> listenToDepartmentQueueLength(String departmentId) {
    return _firestore
        .collection('departments')
        .doc(departmentId)
        .collection('queue')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        final status = doc.data()['status'] as String?;
        return status == 'waiting' || status == 'called';
      }).length;
    });
  }

  // Check if patient already has an active token across departments
  Future<Map<String, dynamic>?> findActivePatientToken(String patientId) async {
    try {
      if (_departments.isEmpty) {
        await fetchDepartments();
      }
      for (var dept in _departments) {
        final snap = await _firestore
            .collection('departments')
            .doc(dept.id)
            .collection('queue')
            .where('patientId', isEqualTo: patientId)
            .get();

        for (var doc in snap.docs) {
          final status = doc.data()['status'] as String?;
          if (status == 'waiting' || status == 'called') {
            final token = QueueToken.fromMap(doc.data(), doc.id);
            _currentPatientToken = token;
            return {
              'departmentId': dept.id,
              'departmentName': dept.name,
              'token': token,
            };
          }
        }
      }
    } catch (e) {
      debugPrint("Error finding active token: $e");
    }
    return null;
  }

  // PATIENT FLOW
  Future<QueueToken?> joinQueue(
    String departmentId,
    String patientId,
    String patientName,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      final queueRef = _firestore
          .collection('departments')
          .doc(departmentId)
          .collection('queue');

      // Check if patient already has an active token
      final existing = await queueRef
          .where('patientId', isEqualTo: patientId)
          .get();

      final hasActive = existing.docs.any((doc) {
        final status = doc.data()['status'] as String?;
        return status == 'waiting' || status == 'called';
      });

      if (hasActive) {
        final activeDoc = existing.docs.firstWhere((doc) {
          final status = doc.data()['status'] as String?;
          return status == 'waiting' || status == 'called';
        });
        _currentPatientToken = QueueToken.fromMap(activeDoc.data(), activeDoc.id);
        return _currentPatientToken;
      }

      // Next waiting token number: if 0 waiting, starts at 1!
      final waitingSnap = await queueRef
          .where('status', isEqualTo: 'waiting')
          .get();

      int nextTokenNumber = waitingSnap.docs.length + 1;

      final newTokenRef = queueRef.doc();
      final newToken = QueueToken(
        id: newTokenRef.id,
        tokenNumber: nextTokenNumber,
        patientId: patientId,
        patientName: patientName,
        status: 'waiting',
        joinedAt: DateTime.now(),
        notifiedAt: null,
      );

      await newTokenRef.set(newToken.toMap());
      _currentPatientToken = newToken;
      return newToken;
    } catch (e) {
      debugPrint("Error joining queue: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<QueueToken?> listenToPatientToken(String departmentId, String patientId) {
    return _firestore
        .collection('departments')
        .doc(departmentId)
        .collection('queue')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
      final activeDocs = snapshot.docs.where((doc) {
        final status = doc.data()['status'] as String?;
        return status == 'waiting' || status == 'called';
      }).toList();

      if (activeDocs.isNotEmpty) {
        activeDocs.sort((a, b) {
          // Called first, then lowest token number
          final aStatus = a.data()['status'] as String?;
          final bStatus = b.data()['status'] as String?;
          if (aStatus == 'called' && bStatus != 'called') return -1;
          if (bStatus == 'called' && aStatus != 'called') return 1;
          final aNum = a.data()['tokenNumber'] as int? ?? 0;
          final bNum = b.data()['tokenNumber'] as int? ?? 0;
          return aNum.compareTo(bNum);
        });

        _currentPatientToken = QueueToken.fromMap(activeDocs.first.data(), activeDocs.first.id);
        return _currentPatientToken;
      }

      // If finished (served or no_show), return latest
      if (snapshot.docs.isNotEmpty) {
        final sortedDocs = snapshot.docs.toList()
          ..sort((a, b) {
            final aDate = (a.data()['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bDate = (b.data()['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bDate.compareTo(aDate);
          });
        return QueueToken.fromMap(sortedDocs.first.data(), sortedDocs.first.id);
      }

      _currentPatientToken = null;
      return null;
    });
  }

  // Recalculates waiting tokens so the first in line is ALWAYS #1, second is #2...
  Future<void> _recalculateTokenNumbers(
    String departmentId, {
    String? excludeTokenId,
    WriteBatch? batch,
  }) async {
    final queueRef = _firestore
        .collection('departments')
        .doc(departmentId)
        .collection('queue');

    final snapshot = await queueRef
        .where('status', isEqualTo: 'waiting')
        .get();

    final docs = snapshot.docs.where((doc) => doc.id != excludeTokenId).toList();
    docs.sort((a, b) {
      final aDate = (a.data()['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bDate = (b.data()['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      return aDate.compareTo(bDate);
    });

    final commitBatch = batch ?? _firestore.batch();
    int currentToken = 1;
    for (var doc in docs) {
      if (doc.data()['tokenNumber'] != currentToken) {
        commitBatch.update(doc.reference, {'tokenNumber': currentToken});
      }
      currentToken++;
    }

    if (batch == null) {
      await commitBatch.commit();
    }
  }

  Future<void> cancelToken(
    String departmentId,
    String tokenId,
    int tokenNumber,
    String patientName,
  ) async {
    try {
      final batch = _firestore.batch();

      // 1. Update Token status to cancelled
      final tokenRef = _firestore
          .collection('departments')
          .doc(departmentId)
          .collection('queue')
          .doc(tokenId);
      batch.update(tokenRef, {'status': 'cancelled'});

      // 2. Add Activity Log
      final logRef = _firestore
          .collection('departments')
          .doc(departmentId)
          .collection('activityLog')
          .doc();
      batch.set(logRef, {
        'tokenNumber': tokenNumber,
        'patientName': patientName,
        'action': 'cancelled',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Renumber remaining waiting tokens so the next waiting patient is #1!
      await _recalculateTokenNumbers(departmentId, excludeTokenId: tokenId, batch: batch);

      await batch.commit();
      _currentPatientToken = null;
      notifyListeners();
    } catch (e) {
      debugPrint("Error cancelling token: $e");
    }
  }

  Future<void> updateNotifiedAt(String departmentId, String tokenId) async {
    await _firestore
        .collection('departments')
        .doc(departmentId)
        .collection('queue')
        .doc(tokenId)
        .update({
      'notifiedAt': FieldValue.serverTimestamp(),
    });
  }

  // ADMIN FLOW
  Stream<List<QueueToken>> listenToAdminQueue(String departmentId) {
    return _firestore
        .collection('departments')
        .doc(departmentId)
        .collection('queue')
        .snapshots()
        .map((snapshot) {
      final activeTokens = snapshot.docs.where((doc) {
        final status = doc.data()['status'] as String?;
        return status == 'waiting' || status == 'called';
      }).toList();

      activeTokens.sort((a, b) {
        // Called first, then waiting by tokenNumber
        final aStatus = a.data()['status'] as String?;
        final bStatus = b.data()['status'] as String?;
        if (aStatus == 'called' && bStatus != 'called') return -1;
        if (bStatus == 'called' && aStatus != 'called') return 1;
        final aNum = a.data()['tokenNumber'] as int? ?? 0;
        final bNum = b.data()['tokenNumber'] as int? ?? 0;
        return aNum.compareTo(bNum);
      });

      _adminQueue = activeTokens
          .map((doc) => QueueToken.fromMap(doc.data(), doc.id))
          .toList();

      return _adminQueue;
    });
  }

  Stream<List<ActivityLog>> listenToActivityLog(String departmentId) {
    return _firestore
        .collection('departments')
        .doc(departmentId)
        .collection('activityLog')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ActivityLog.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Calls next waiting patient and shifts remaining waiting tokens so the next person becomes #1!
  Future<void> callNextPatient(String departmentId) async {
    try {
      final queueRef = _firestore
          .collection('departments')
          .doc(departmentId)
          .collection('queue');

      final snap = await queueRef
          .where('status', isEqualTo: 'waiting')
          .get();

      if (snap.docs.isEmpty) {
        debugPrint("No waiting patients in queue.");
        return;
      }

      final docs = snap.docs.toList();
      docs.sort((a, b) {
        final aNum = a.data()['tokenNumber'] as int? ?? 0;
        final bNum = b.data()['tokenNumber'] as int? ?? 0;
        return aNum.compareTo(bNum);
      });

      final nextWaitingDoc = docs.first;
      final batch = _firestore.batch();

      // 1. Mark this waiting patient as 'called'
      batch.update(nextWaitingDoc.reference, {'status': 'called'});

      // 2. Renumber remaining waiting patients: the new first waiting person becomes #1!
      int nextNum = 1;
      for (int i = 1; i < docs.length; i++) {
        batch.update(docs[i].reference, {'tokenNumber': nextNum});
        nextNum++;
      }

      await batch.commit();
      notifyListeners();
    } catch (e) {
      debugPrint("Error calling next patient: $e");
    }
  }

  // Marks patient as served or no-show and renumbers remaining waiting tokens
  Future<void> markTokenDone(
    String departmentId,
    QueueToken token,
    bool isNoShow,
  ) async {
    try {
      final batch = _firestore.batch();
      final status = isNoShow ? 'no_show' : 'served';

      // 1. Update Token status
      final tokenRef = _firestore
          .collection('departments')
          .doc(departmentId)
          .collection('queue')
          .doc(token.id);
      batch.update(tokenRef, {'status': status});

      // 2. Activity Log
      final logRef = _firestore
          .collection('departments')
          .doc(departmentId)
          .collection('activityLog')
          .doc();
      batch.set(logRef, {
        'tokenNumber': token.tokenNumber,
        'patientName': token.patientName,
        'action': status,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Recalculate remaining waiting tokens so the first in line is #1
      await _recalculateTokenNumbers(departmentId, excludeTokenId: token.id, batch: batch);

      await batch.commit();
      notifyListeners();
    } catch (e) {
      debugPrint("Error marking done: $e");
    }
  }
}
