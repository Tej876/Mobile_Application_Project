import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLog {
  final String id;
  final int tokenNumber;
  final String patientName;
  final String action; // "served" | "no_show" | "cancelled"
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.tokenNumber,
    required this.patientName,
    required this.action,
    required this.timestamp,
  });

  factory ActivityLog.fromMap(Map<String, dynamic> data, String documentId) {
    return ActivityLog(
      id: documentId,
      tokenNumber: data['tokenNumber']?.toInt() ?? 0,
      patientName: data['patientName'] ?? '',
      action: data['action'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tokenNumber': tokenNumber,
      'patientName': patientName,
      'action': action,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
