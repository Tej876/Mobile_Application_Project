import 'package:cloud_firestore/cloud_firestore.dart';

class QueueToken {
  final String id;
  final int tokenNumber;
  final String patientId;
  final String patientName;
  final String status; // "waiting" | "called" | "served" | "no_show" | "cancelled"
  final DateTime joinedAt;
  final DateTime? notifiedAt;

  QueueToken({
    required this.id,
    required this.tokenNumber,
    required this.patientId,
    required this.patientName,
    required this.status,
    required this.joinedAt,
    this.notifiedAt,
  });

  factory QueueToken.fromMap(Map<String, dynamic> data, String documentId) {
    return QueueToken(
      id: documentId,
      tokenNumber: data['tokenNumber']?.toInt() ?? 0,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
      status: data['status'] ?? 'waiting',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notifiedAt: (data['notifiedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tokenNumber': tokenNumber,
      'patientId': patientId,
      'patientName': patientName,
      'status': status,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'notifiedAt': notifiedAt != null ? Timestamp.fromDate(notifiedAt!) : null,
    };
  }
}
