import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

Map<String, dynamic> _profileJson({Map<String, dynamic>? extra}) =>
    <String, dynamic>{
      'id': 'profile-1',
      'userId': 'user-1',
      'first_name': 'Jane',
      'last_name': 'Doe',
      'email': 'jane.doe@example.com',
      'phone': '+1234567890',
      'username': 'janedoe',
      'avatar_url': 'https://example.com/avatar.png',
      'default_avatar_url': 'https://example.com/default.png',
      'created_at': '2026-01-01T10:00:00.000Z',
      'is_active': true,
      'is_verified': true,
      'is_onboarded': true,
      'organisation_id': 'org-1',
      'current_organisation_slug': 'acme',
      ...?extra,
    };

void main() {
  group('ProfileModel.fromJson', () {
    test('parses basic profile attributes', () {
      final model = ProfileModel.fromJson(_profileJson());

      expect(model.id, 'user-1');
      expect(model.firstName, 'Jane');
      expect(model.lastName, 'Doe');
      expect(model.email, 'jane.doe@example.com');
      expect(model.currentOrg, 'org-1');
      expect(model.currentOrganisationSlug, 'acme');
      expect(model.status.hasCustomStatus, isFalse);
      expect(model.status.emoji, isNull);
      expect(model.status.text, isNull);
      expect(model.status.online, isTrue);
    });

    test(
      'parses flat custom status fields (icon, text, pause_notification, online)',
      () {
        final futureExpiry = DateTime.now().add(const Duration(hours: 2));
        final model = ProfileModel.fromJson(
          _profileJson(
            extra: {
              'icon': '\u{1F44B}',
              'text': 'In a meeting',
              'pause_notification': true,
              'online': false,
              'status_timeout': futureExpiry.toIso8601String(),
            },
          ),
        );

        expect(model.status.emoji, '\u{1F44B}');
        expect(model.status.text, 'In a meeting');
        expect(model.status.pauseNotifications, isTrue);
        expect(model.status.online, isFalse);
        expect(
          model.status.expiresAt?.millisecondsSinceEpoch,
          closeTo(futureExpiry.millisecondsSinceEpoch, 1000),
        );
        expect(model.status.hasCustomStatus, isTrue);
      },
    );

    test('parses nested status map', () {
      final model = ProfileModel.fromJson(
        _profileJson(
          extra: {
            'status': {
              'emoji': '\u{1F4BB}',
              'text': 'Coding',
              'pause_notifications': false,
              'online': true,
              'status_timeout': 'dont-clear',
            },
          },
        ),
      );

      expect(model.status.emoji, '\u{1F4BB}');
      expect(model.status.text, 'Coding');
      expect(model.status.pauseNotifications, isFalse);
      expect(model.status.online, isTrue);
      expect(model.status.expiresAt, isNull);
      expect(model.status.hasCustomStatus, isTrue);
    });

    test('parses epoch seconds timestamp in status_timeout', () {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      final model = ProfileModel.fromJson(
        _profileJson(
          extra: {
            'emoji': '\u{1F3AF}',
            'text': 'Focused',
            'status_timeout': nowSec,
          },
        ),
      );

      expect(model.status.emoji, '\u{1F3AF}');
      expect(model.status.text, 'Focused');
      expect(model.status.expiresAt?.millisecondsSinceEpoch, nowSec * 1000);
    });

    test('parses human-readable status timeout string like "30 minutes"', () {
      final before = DateTime.now();
      final model = ProfileModel.fromJson(
        _profileJson(
          extra: {
            'icon': '\u{2615}',
            'text': 'Grabbing coffee',
            'status_timeout': '30 minutes',
          },
        ),
      );

      expect(model.status.emoji, '\u{2615}');
      expect(model.status.text, 'Grabbing coffee');
      expect(model.status.expiresAt, isNotNull);
      final diff = model.status.expiresAt!.difference(before);
      expect(diff.inMinutes, closeTo(30, 1));
    });

    test('maps parsed status onto User entity via toEntity()', () {
      final model = ProfileModel.fromJson(
        _profileJson(
          extra: {'icon': '\u{1F680}', 'text': 'Deploying', 'online': true},
        ),
      );

      final user = model.toEntity();

      expect(user.id, 'user-1');
      expect(user.status.emoji, '\u{1F680}');
      expect(user.status.text, 'Deploying');
      expect(user.status.online, isTrue);
      expect(user.status.hasCustomStatus, isTrue);
    });
  });
}
