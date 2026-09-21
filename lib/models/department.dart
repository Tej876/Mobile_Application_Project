class Department {
  final String id;
  final String name;
  final int avgConsultationMins;

  Department({
    required this.id,
    required this.name,
    required this.avgConsultationMins,
  });

  factory Department.fromMap(Map<String, dynamic> data, String documentId) {
    return Department(
      id: documentId,
      name: data['name'] ?? '',
      avgConsultationMins: data['avgConsultationMins']?.toInt() ?? 10,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'avgConsultationMins': avgConsultationMins,
    };
  }
}
