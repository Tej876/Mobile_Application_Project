class AppUser {
  final String uid; // Maps to Firebase UID
  final String? mongoId; // MongoDB _id
  final String role; // 'patient' | 'admin'
  final String name;
  final String email;

  AppUser({
    required this.uid,
    this.mongoId,
    required this.role,
    required this.name,
    required this.email,
  });

  factory AppUser.fromJson(Map<String, dynamic> json, {String? defaultUid}) {
    return AppUser(
      uid: json['firebaseUid'] ?? json['uid'] ?? defaultUid ?? '',
      mongoId: json['id'] ?? json['_id'],
      role: json['role'] ?? 'patient',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
    );
  }

  // Backwards compatibility factory for legacy calls
  factory AppUser.fromMap(Map<String, dynamic> data, String documentId) {
    return AppUser.fromJson(data, defaultUid: documentId);
  }

  Map<String, dynamic> toJson() {
    return {
      'firebaseUid': uid,
      'uid': uid,
      'id': mongoId,
      'role': role,
      'name': name,
      'email': email,
    };
  }

  Map<String, dynamic> toMap() => toJson();
}
