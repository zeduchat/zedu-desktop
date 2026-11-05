import '../../../../../helpers/helpers.dart';
import 'package:zedu/features/features.dart';

Map<String, dynamic> _userJson() => Map<String, dynamic>.from(
  LoginResponseModel.mockLoginResponse['user'] as Map<String, dynamic>,
);

void main() {
  group('UserModel.fromJson', () {
    test('parses epoch-second strings', () {
      final user = UserModel.fromJson(_userJson());

      expect(
        user.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1778373782 * 1000),
      );
      expect(user.username, 'aloaderemi');
    });

    test('defaults null optional strings to empty', () {
      final json = _userJson()
        ..['phone'] = null
        ..['avatar_url'] = null
        ..['default_avatar_url'] = null
        ..['current_org'] = null
        ..['current_organisation_slug'] = null
        ..['first_name'] = null
        ..['last_name'] = null
        ..['fullname'] = null
        ..['username'] = null;

      final user = UserModel.fromJson(json);

      expect(user.phone, '');
      expect(user.avatarUrl, '');
      expect(user.defaultAvatarUrl, '');
      expect(user.currentOrg, '');
      expect(user.currentOrganisationSlug, '');
      expect(user.firstName, '');
      expect(user.username, '');
    });

    test('accepts numeric and ISO-8601 timestamps', () {
      final json = _userJson()
        ..['created_at'] = 1778373782
        ..['updated_at'] = '2026-05-10T02:43:02Z'
        ..['expires_in'] = 1778991491.0;

      final user = UserModel.fromJson(json);

      expect(
        user.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1778373782 * 1000),
      );
      expect(user.updatedAt, DateTime.utc(2026, 5, 10, 2, 43, 2));
      expect(
        user.expiresIn,
        DateTime.fromMillisecondsSinceEpoch(1778991491 * 1000),
      );
    });

    test('falls back to epoch 0 for missing timestamps', () {
      final json = _userJson()
        ..remove('created_at')
        ..['updated_at'] = 'not a date';

      final user = UserModel.fromJson(json);

      expect(user.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(user.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('falls back to id when user_id is missing', () {
      final json = _userJson()..remove('user_id');

      expect(UserModel.fromJson(json).userId, json['id']);
    });
  });
}
