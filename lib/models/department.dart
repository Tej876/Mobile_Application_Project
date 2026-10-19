class Department {
  final String id;
  final String name;
  final int avgConsultationMins;
  final int activeQueueLength;

  Department({
    required this.id,
    required this.name,
    required this.avgConsultationMins,
    this.activeQueueLength = 0,
  });

  factory Department.fromJson(Map<String, dynamic> json, {String? defaultId}) {
    return Department(
      id: json['id'] ?? json['_id'] ?? defaultId ?? '',
      name: json['name'] ?? '',
      avgConsultationMins: (json['avgConsultationMins'] as num?)?.toInt() ?? 10,
      activeQueueLength: (json['activeQueueLength'] as num?)?.toInt() ?? 0,
    );
  }

  // Backwards compatibility factory
  factory Department.fromMap(Map<String, dynamic> data, String documentId) {
    return Department.fromJson(data, defaultId: documentId);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avgConsultationMins': avgConsultationMins,
      'activeQueueLength': activeQueueLength,
    };
  }

  Map<String, dynamic> toMap() => toJson();
}
