import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

User buildSessionUser({
  String firstName = 'Ada',
  String lastName = 'Okafor',
  String email = 'ada@zedu.chat',
  String username = 'ada',
  String avatarUrl = 'https://example.com/session.png',
}) {
  return User(
    id: 'user-ada',
    firstName: firstName,
    lastName: lastName,
    email: email,
    phone: '+2348012345678',
    username: username,
    isVerified: true,
    isOnboarded: true,
    createdAt: DateTime(2026, 1, 1),
    currentOrg: 'org-1',
    currentOrganisationSlug: 'org-slug',
    avatarUrl: avatarUrl,
    defaultAvatarUrl: 'https://example.com/default.png',
  );
}

ProfileAccount buildAccount({
  String name = 'Stored Name',
  String email = 'stored@zedu.chat',
  String timezone = 'Africa/Lagos',
  String? avatarUrl = 'https://example.com/stored.png',
  String username = 'storedname',
}) {
  return ProfileAccount(
    name: name,
    email: email,
    timezone: timezone,
    avatarUrl: avatarUrl,
    username: username,
  );
}

void main() {
  group('profileAccountFromAuthUser', () {
    test('builds account from authenticated user data', () {
      final account = profileAccountFromAuthUser(buildSessionUser());

      expect(account.name, 'Ada Okafor');
      expect(account.email, 'ada@zedu.chat');
      expect(account.username, 'ada');
      expect(account.avatarUrl, 'https://example.com/session.png');
    });

    test('falls back to username when fullname is empty', () {
      final user = buildSessionUser(firstName: '', lastName: '');
      final account = profileAccountFromAuthUser(user);

      expect(account.name, 'ada');
      expect(account.email, 'ada@zedu.chat');
    });

    test('does not use placeholder values', () {
      final account = profileAccountFromAuthUser(buildSessionUser());

      expect(account.name, isNot('Anonymous user'));
      expect(account.email, isNot('anonymoususer@email.com'));
      expect(account.username, isNot('anonymoususer'));
    });
  });

  group('accountForAuthenticatedUser', () {
    group('name', () {
      test('uses the session name when empty', () {
        final account = accountForAuthenticatedUser(
          buildAccount(name: ''),
          buildSessionUser(),
        );

        expect(account.name, 'Ada Okafor');
      });

      test('uses the session name when it is the placeholder', () {
        final account = accountForAuthenticatedUser(
          buildAccount(name: 'Anonymous user'),
          buildSessionUser(),
        );

        expect(account.name, 'Ada Okafor');
      });

      test('keeps a real name', () {
        final account = accountForAuthenticatedUser(
          buildAccount(),
          buildSessionUser(),
        );

        expect(account.name, 'Stored Name');
      });
    });

    group('email', () {
      test('uses the session email when empty', () {
        final account = accountForAuthenticatedUser(
          buildAccount(email: ''),
          buildSessionUser(),
        );

        expect(account.email, 'ada@zedu.chat');
      });

      test('uses the session email when it is the placeholder', () {
        final account = accountForAuthenticatedUser(
          buildAccount(email: 'anonymoususer@email.com'),
          buildSessionUser(),
        );

        expect(account.email, 'ada@zedu.chat');
      });

      test('keeps a real email', () {
        final account = accountForAuthenticatedUser(
          buildAccount(),
          buildSessionUser(),
        );

        expect(account.email, 'stored@zedu.chat');
      });
    });

    group('username', () {
      test('uses the session username when empty', () {
        final account = accountForAuthenticatedUser(
          buildAccount(username: ''),
          buildSessionUser(),
        );

        expect(account.username, 'ada');
      });

      test('uses the session username when it is the placeholder', () {
        final account = accountForAuthenticatedUser(
          buildAccount(username: 'anonymoususer'),
          buildSessionUser(),
        );

        expect(account.username, 'ada');
      });

      test('keeps a real username', () {
        final account = accountForAuthenticatedUser(
          buildAccount(),
          buildSessionUser(),
        );

        expect(account.username, 'storedname');
      });
    });

    group('avatarUrl', () {
      test('uses the session avatar when null', () {
        final account = accountForAuthenticatedUser(
          buildAccount(avatarUrl: null),
          buildSessionUser(),
        );

        expect(account.avatarUrl, 'https://example.com/session.png');
      });

      test('uses the session avatar when whitespace', () {
        final account = accountForAuthenticatedUser(
          buildAccount(avatarUrl: '   '),
          buildSessionUser(),
        );

        expect(account.avatarUrl, 'https://example.com/session.png');
      });

      test('keeps a real avatar', () {
        final account = accountForAuthenticatedUser(
          buildAccount(),
          buildSessionUser(),
        );

        expect(account.avatarUrl, 'https://example.com/stored.png');
      });
    });
  });
}
