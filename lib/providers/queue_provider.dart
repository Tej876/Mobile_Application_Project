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

      // Seed common departments if they don't exist
      if (snapshot.docs.length < 6) {
        final existingNames = snapshot.docs.map((d) => d.data()['name'] as String? ?? '').toList();
        final standardDepts = [
          {'name': 'General Medicine', 'avgConsultationMins': 15},
          {'name': 'Cardiology', 'avgConsultationMins': 20},
          {'name': 'Orthopedics', 'avgConsultationMins': 25},
          {'name': 'Pediatrics', 'avgConsultationMins': 15},
          {'name': 'Dermatology', 'avgConsultationMins': 10},
          {'name': 'Neurology', 'avgConsultationMins': 30},
        ];
        
        final batch = _firestore.batch();
        bool addedAny = false;
        
        for (var dept in standardDepts) {
          if (!existingNames.any((name) => name.toLowerCase() == (dept['name'] as String).toLowerCase())) {
            final doc = _firestore.collection('departments').doc();
            batch.set(doc, dept);
            addedAny = true;
          }
        }
        
        if (addedAny) {
          await batch.commit();
          // Refetch after adding
          snapshot = await _firestore.collection('departments').get();
        }
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

      final snapshot = await queueRef.where('status', whereIn: ['waiting', 'called']).get();
      
      int nextTokenNumber = snapshot.docs.length + 1;

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
        return _currentPatientToken;
      }
      _currentPatientToken = null;
      return null;
    });
  }
  


  Future<void> _recalculateTokenNumbers(String departmentId, {String? excludeTokenId, WriteBatch? batch}) async {
    final queueRef = _firestore.collection('departments').doc(departmentId).collection('queue');
    final snapshot = await queueRef.where('status', whereIn: ['waiting', 'called']).get();
    
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
      
      // 3. Recalculate remaining tokens
      await _recalculateTokenNumbers(departmentId, excludeTokenId: tokenId, batch: batch);
      
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
      
      // Recalculate remaining tokens
      await _recalculateTokenNumbers(departmentId, excludeTokenId: token.id, batch: batch);
      
      await batch.commit();
    } catch(e) {
      debugPrint("Error marking done: $e");
    }
  }
}
