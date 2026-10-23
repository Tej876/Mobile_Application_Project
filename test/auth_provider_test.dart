import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/services/api_service.dart';
import 'package:queueless/services/profile_sync.dart';

void main() {
  group('fetchProfileWithPatientRecovery', () {
    test('recovers only when the profile request returns 404', () async {
      var recoveryCalls = 0;

      final result = await fetchProfileWithPatientRecovery(
        fetchProfile: () async =>
            throw ApiException(statusCode: 404, message: 'Profile not found'),
        recoverPatientProfile: () async {
          recoveryCalls++;
          return {
            'user': {'role': 'patient'},
          };
        },
        allowPatientRecovery: true,
      );

      expect(recoveryCalls, 1);
      expect(result['user']['role'], 'patient');
    });

    test(
      'does not recover when the caller is not in the patient portal',
      () async {
        var recoveryCalls = 0;

        await expectLater(
          fetchProfileWithPatientRecovery(
            fetchProfile: () async => throw ApiException(
              statusCode: 404,
              message: 'Profile not found',
            ),
            recoverPatientProfile: () async {
              recoveryCalls++;
              return {};
            },
            allowPatientRecovery: false,
          ),
          throwsA(isA<ApiException>()),
        );

        expect(recoveryCalls, 0);
      },
    );

    for (final statusCode in [0, 401, 500, 503]) {
      test('does not recover for status $statusCode', () async {
        var recoveryCalls = 0;

        await expectLater(
          fetchProfileWithPatientRecovery(
            fetchProfile: () async => throw ApiException(
              statusCode: statusCode,
              message: 'Request failed',
            ),
            recoverPatientProfile: () async {
              recoveryCalls++;
              return {};
            },
            allowPatientRecovery: true,
          ),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'statusCode',
              statusCode,
            ),
          ),
        );

        expect(recoveryCalls, 0);
      });
    }
  });
}
