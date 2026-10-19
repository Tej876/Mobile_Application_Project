class QueueToken {
  final String id;
  final String departmentId;
  final int tokenNumber;
  final String patientId;
  final String patientName;
  final String status; // "waiting" | "called" | "served" | "no_show" | "cancelled"
  final DateTime joinedAt;
  final DateTime? calledAt;
  final DateTime? servedAt;
  final DateTime? cancelledAt;
  final DateTime? notifiedAt;
  final int position;
  final int estWaitMins;

  QueueToken({
    required this.id,
    this.departmentId = '',
    required this.tokenNumber,
    required this.patientId,
    required this.patientName,
    required this.status,
    required this.joinedAt,
    this.calledAt,
    this.servedAt,
    this.cancelledAt,
    this.notifiedAt,
    this.position = 0,
    this.estWaitMins = 0,
  });

  static DateTime _parseDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    try {
      // Dynamic fallback for legacy Firestore Timestamp if present
      final dynamic ts = val;
      if (ts.toDate != null) return ts.toDate();
    } catch (_) {}
    return DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    try {
      final dynamic ts = val;
      if (ts.toDate != null) return ts.toDate();
    } catch (_) {}
    return null;
  }

  factory QueueToken.fromJson(Map<String, dynamic> json, {String? defaultId}) {
    return QueueToken(
      id: json['id'] ?? json['_id'] ?? defaultId ?? '',
      departmentId: json['departmentId'] is Map
          ? (json['departmentId']['id'] ?? json['departmentId']['_id'] ?? '')
          : (json['departmentId'] ?? ''),
      tokenNumber: (json['tokenNumber'] as num?)?.toInt() ?? 0,
      patientId: json['patientId'] ?? '',
      patientName: json['patientName'] ?? '',
      status: json['status'] ?? 'waiting',
      joinedAt: _parseDate(json['joinedAt']),
      calledAt: _parseNullableDate(json['calledAt']),
      servedAt: _parseNullableDate(json['servedAt']),
      cancelledAt: _parseNullableDate(json['cancelledAt']),
      notifiedAt: _parseNullableDate(json['notifiedAt']),
      position: (json['position'] as num?)?.toInt() ?? 0,
      estWaitMins: (json['estWaitMins'] as num?)?.toInt() ?? 0,
    );
  }

  // Backwards compatibility factory
  factory QueueToken.fromMap(Map<String, dynamic> data, String documentId) {
    return QueueToken.fromJson(data, defaultId: documentId);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'departmentId': departmentId,
      'tokenNumber': tokenNumber,
      'patientId': patientId,
      'patientName': patientName,
      'status': status,
      'joinedAt': joinedAt.toIso8601String(),
      'calledAt': calledAt?.toIso8601String(),
      'servedAt': servedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'notifiedAt': notifiedAt?.toIso8601String(),
      'position': position,
      'estWaitMins': estWaitMins,
    };
  }

  Map<String, dynamic> toMap() => toJson();
}
