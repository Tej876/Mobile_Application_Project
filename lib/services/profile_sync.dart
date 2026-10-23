import 'api_service.dart';

Future<dynamic> fetchProfileWithPatientRecovery({
  required Future<dynamic> Function() fetchProfile,
  required Future<dynamic> Function() recoverPatientProfile,
  required bool allowPatientRecovery,
}) async {
  try {
    return await fetchProfile();
  } on ApiException catch (error) {
    if (error.statusCode != 404 || !allowPatientRecovery) {
      rethrow;
    }
    return recoverPatientProfile();
  }
}
