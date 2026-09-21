class AppUser {
  final String uid;
  final String role;
  final String name;
  final String email;

  AppUser({
    required this.uid,
    required this.role,
    required this.name,
    required this.email,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String documentId) {
    return AppUser(
      uid: documentId,
      role: data['role'] ?? 'patient',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'name': name,
      'email': email,
    };
  }
}
