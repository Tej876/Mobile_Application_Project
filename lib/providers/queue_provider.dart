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

  int _currentPatientPosition = 0;
  int get currentPatientPosition => _currentPatientPosition;
  
  List<QueueToken> _adminQueue = [];
  List<QueueToken> get adminQueue => _adminQueue;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchDepartments() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('departments').get();
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

  // PATIENT FLOW
  Future<void> joinQueue(String departmentId, String patientId, String patientName) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check if patient already has an active token
      final queueRef = _firestore.collection('departments').doc(departmentId).collection('queue');
      final existing = await queueRef.where('patientId', isEqualTo: patientId).get();
          
      final hasActive = existing.docs.any((doc) {
        final status = doc.data()['status'] as String?;
        return status == 'waiting' || status == 'called';
      });

      if (hasActive) {
        return; // Patient already in queue, just return
      }

      // Find the max token number
      final snapshot = await queueRef.orderBy('tokenNumber', descending: true).limit(1).get();
      
      int nextTokenNumber = 1;
      if (snapshot.docs.isNotEmpty) {
        nextTokenNumber = (snapshot.docs.first.data()['tokenNumber'] ?? 0) + 1;
      }

      final newTokenRef = queueRef.doc();
      final newToken = QueueToken(
        id: newTokenRef.id,
        tokenNumber: nextTokenNumber,
        patientId: patientId,
        patientName: patientName,
        status: 'waiting',
        joinedAt: DateTime.now(),
      );

      await newTokenRef.set(newToken.toMap());
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
      
      // Filter active tokens in Dart to avoid index issues
      final activeDocs = snapshot.docs.where((doc) {
        final status = doc.data()['status'] as String?;
        return status == 'waiting' || status == 'called';
      }).toList();

      if (activeDocs.isNotEmpty) {
        // Sort to get the latest token if there are duplicates from previous bugs
        activeDocs.sort((a, b) {
          final aNum = a.data()['tokenNumber'] as int? ?? 0;
          final bNum = b.data()['tokenNumber'] as int? ?? 0;
          return bNum.compareTo(aNum);
        });
        
        _currentPatientToken = QueueToken.fromMap(activeDocs.first.data(), activeDocs.first.id);
        _calculatePatientPosition(departmentId);
        return _currentPatientToken;
      }
      _currentPatientToken = null;
      return null;
    });
  }
  
  void _calculatePatientPosition(String departmentId) async {
    if (_currentPatientToken == null) return;
    try {
      final snapshot = await _firestore
          .collection('departments')
          .doc(departmentId)
          .collection('queue')
          .get();
          
      int pos = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final tNum = data['tokenNumber'] as int? ?? 0;
        
        if ((status == 'waiting' || status == 'called') && tNum <= _currentPatientToken!.tokenNumber) {
          pos++;
        }
      }
      
      _currentPatientPosition = pos;
      notifyListeners();
    } catch(e) {
      debugPrint("Error calculating position: $e");
    }
  }

  Future<void> cancelToken(String departmentId, String tokenId, int tokenNumber, String patientName) async {
    try {
      final batch = _firestore.batch();
      
      // 1. Update Token status
      final tokenRef = _firestore.collection('departments').doc(departmentId).collection('queue').doc(tokenId);
      batch.update(tokenRef, {'status': 'cancelled'});
      
      // 2. Add Activity Log
      final logRef = _firestore.collection('departments').doc(departmentId).collection('activityLog').doc();
      batch.set(logRef, {
        'tokenNumber': tokenNumber,
        'patientName': patientName,
        'action': 'cancelled',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      _currentPatientToken = null;
      notifyListeners();
    } catch(e) {
      debugPrint("Error cancelling token: $e");
    }
  }

  Future<void> updateNotifiedAt(String departmentId, String tokenId) async {
     await _firestore.collection('departments').doc(departmentId).collection('queue').doc(tokenId).update({
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
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
            .map((doc) => ActivityLog.fromMap(doc.data(), doc.id))
            .toList();
        });
  }

  Future<void> callNextPatient(String departmentId) async {
    // Find the first 'waiting' token
    final waitingToken = _adminQueue.firstWhere((t) => t.status == 'waiting', orElse: () => throw Exception("No waiting patients"));
    
    await _firestore
        .collection('departments')
        .doc(departmentId)
        .collection('queue')
        .doc(waitingToken.id)
        .update({'status': 'called'});
  }

  Future<void> markTokenDone(String departmentId, QueueToken token, bool isNoShow) async {
    try {
      final batch = _firestore.batch();
      final status = isNoShow ? 'no_show' : 'served';
      
      // Update Token
      final tokenRef = _firestore.collection('departments').doc(departmentId).collection('queue').doc(token.id);
      batch.update(tokenRef, {'status': status});
      
      // Activity Log
      final logRef = _firestore.collection('departments').doc(departmentId).collection('activityLog').doc();
      batch.set(logRef, {
        'tokenNumber': token.tokenNumber,
        'patientName': token.patientName,
        'action': status,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
    } catch(e) {
      debugPrint("Error marking done: $e");
    }
  }
}
