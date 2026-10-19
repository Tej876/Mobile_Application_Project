class ActivityLog {
  final String id;
  final int tokenNumber;
  final String patientName;
  final String action; // "served" | "no_show" | "cancelled" | "token_called" etc.
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.tokenNumber,
    required this.patientName,
    required this.action,
    required this.timestamp,
  });

  static DateTime _parseDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    try {
      final dynamic ts = val;
      if (ts.toDate != null) return ts.toDate();
    } catch (_) {}
    return DateTime.now();
  }

  factory ActivityLog.fromJson(Map<String, dynamic> json, {String? defaultId}) {
    return ActivityLog(
      id: json['id'] ?? json['_id'] ?? defaultId ?? '',
      tokenNumber: (json['tokenNumber'] as num?)?.toInt() ?? 0,
      patientName: json['patientName'] ?? '',
      action: json['action'] ?? '',
      timestamp: _parseDate(json['timestamp']),
    );
  }

  factory ActivityLog.fromMap(Map<String, dynamic> data, String documentId) {
    return ActivityLog.fromJson(data, defaultId: documentId);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tokenNumber': tokenNumber,
      'patientName': patientName,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();
}
