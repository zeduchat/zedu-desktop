import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/auth/data/models/login_response_model.dart';

void main() {
  group('LoginResponseModel and UserModel timestamp parsing (#2574)', () {
    final mockUser = Map<String, dynamic>.from(
      LoginResponseModel.mockLoginResponse['user'] as Map<String, dynamic>,
    );

    test('parses when timestamps are integer epoch numbers', () {
      final userJson = Map<String, dynamic>.from(mockUser)
        ..['created_at'] = 1778373782
        ..['updated_at'] = 1778386691
        ..['expires_in'] = 1778991491;

      final loginJson = <String, dynamic>{
        'access_token': 'test-token',
        'access_token_expires_in': 1778991491,
        'notification_token': 'notif-token',
        'user': userJson,
      };

      final response = LoginResponseModel.fromJson(loginJson);
      expect(response.accessTokenExpiresIn.millisecondsSinceEpoch, 1778991491 * 1000);
      expect(response.user.createdAt.millisecondsSinceEpoch, 1778373782 * 1000);
      expect(response.user.updatedAt.millisecondsSinceEpoch, 1778386691 * 1000);
      expect(response.user.expiresIn.millisecondsSinceEpoch, 1778991491 * 1000);
    });

    test('parses when timestamps are string epoch values', () {
      final userJson = Map<String, dynamic>.from(mockUser)
        ..['created_at'] = '1778373782'
        ..['updated_at'] = '1778386691'
        ..['expires_in'] = '1778991491';

      final loginJson = <String, dynamic>{
        'access_token': 'test-token',
        'access_token_expires_in': '1778991491',
        'notification_token': 'notif-token',
        'user': userJson,
      };

      final response = LoginResponseModel.fromJson(loginJson);
      expect(response.accessTokenExpiresIn.millisecondsSinceEpoch, 1778991491 * 1000);
      expect(response.user.createdAt.millisecondsSinceEpoch, 1778373782 * 1000);
      expect(response.user.updatedAt.millisecondsSinceEpoch, 1778386691 * 1000);
      expect(response.user.expiresIn.millisecondsSinceEpoch, 1778991491 * 1000);
    });

    test('parses when timestamps are ISO-8601 strings', () {
      const isoString = '2026-05-10T02:43:02.443874Z';
      final expectedDate = DateTime.parse(isoString);

      final userJson = Map<String, dynamic>.from(mockUser)
        ..['created_at'] = isoString
        ..['updated_at'] = isoString
        ..['expires_in'] = isoString;

      final loginJson = <String, dynamic>{
        'access_token': 'test-token',
        'access_token_expires_in': isoString,
        'notification_token': 'notif-token',
        'user': userJson,
      };

      final response = LoginResponseModel.fromJson(loginJson);
      expect(response.accessTokenExpiresIn, expectedDate);
      expect(response.user.createdAt, expectedDate);
      expect(response.user.updatedAt, expectedDate);
      expect(response.user.expiresIn, expectedDate);
    });

    test('falls back gracefully on null or invalid timestamps without throwing', () {
      final userJson = Map<String, dynamic>.from(mockUser)
        ..['created_at'] = null
        ..['updated_at'] = 'invalid-date'
        ..['expires_in'] = null;

      final loginJson = <String, dynamic>{
        'access_token': 'test-token',
        'access_token_expires_in': null,
        'notification_token': 'notif-token',
        'user': userJson,
      };

      final response = LoginResponseModel.fromJson(loginJson);
      expect(response.accessTokenExpiresIn.millisecondsSinceEpoch, 0);
      expect(response.user.createdAt.millisecondsSinceEpoch, 0);
      expect(response.user.updatedAt.millisecondsSinceEpoch, 0);
      expect(response.user.expiresIn.millisecondsSinceEpoch, 0);
    });
  });
}
