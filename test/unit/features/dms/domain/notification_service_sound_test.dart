import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

final _me = User(
  id: 'me',
  firstName: 'Dave',
  lastName: 'Tolu',
  email: 'me@zedu.chat',
  phone: '',
  username: 'me',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026, 10, 16),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'org-1',
  avatarUrl: '',
  defaultAvatarUrl: '',
);

class _Auth extends AuthNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: _me);
}

class _FakeSound implements MessageSound {
  int plays = 0;

  @override
  Future<void> play() async => plays++;

  @override
  Future<void> dispose() async {}
}

class _MemoryStorage extends Fake implements SecureStorageService {
  final values = <String, String>{};

  @override
  Future<String?> readData(String key) async => values[key];

  @override
  Future<void> writeData(String key, String value) async => values[key] = value;
}

const _allowed = NotificationPreferences(
  mode: NotificationMode.allMessages,
  quietHoursEnabled: false,
  pauseFrom: 0,
  resumeAt: 0,
  emailNotifications: false,
  differentMobileSettings: false,
  timezone: 'Africa/Lagos',
);

Map<String, dynamic> _message(String from) => {
  'id': 'm-$from',
  'user_id': from,
  'content': 'Hello',
};

void main() {
  // Building a LocalNotification touches the plugin's platform channel.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSound sound;
  late List<LocalNotification> shown;
  late bool focused;

  Future<void> Function(LocalNotification)? show;

  ProviderContainer makeContainer({
    NotificationPreferences? preferences = _allowed,
  }) {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_Auth.new),
        currentOrgIdProvider.overrideWithValue('org-1'),
        desktopNotificationPreferencesProvider.overrideWith(
          (ref) async => preferences,
        ),
        messageSoundProvider.overrideWithValue(sound),
        notificationServiceProvider.overrideWith(
          (ref) => NotificationService(
            ref,
            null,
            () async {},
            () async => focused,
            show ?? (notification) async => shown.add(notification),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> receive(
    ProviderContainer container, {
    String from = 'u-ada',
    String channelId = 'c-ada',
    bool forceShow = false,
  }) async {
    // Lets the (overridden) notification preferences load first.
    await container.read(desktopNotificationPreferencesProvider.future);
    await container
        .read(notificationServiceProvider)
        .handleIncomingMessage(
          _message(from),
          channelId,
          'Ada',
          forceShow: forceShow,
        );
  }

  setUp(() {
    sound = _FakeSound();
    shown = [];
    focused = false;
    show = null;
  });

  group('the message sound', () {
    test('plays once when a notification is shown', () async {
      final container = makeContainer();

      await receive(container);

      expect(shown, hasLength(1));
      expect(sound.plays, 1);
    });

    test('does not play when the setting is off', () async {
      final container = makeContainer();
      container.read(messageSoundEnabledProvider.notifier).setEnabled(false);

      await receive(container);

      expect(shown, hasLength(1));
      expect(sound.plays, 0);
    });

    test('does not play while notifications are paused', () async {
      final container = makeContainer();
      container
          .read(notificationSettingsProvider.notifier)
          .setDndMode(const Duration(hours: 1));

      await receive(container);

      expect(shown, isEmpty);
      expect(sound.plays, 0);
    });

    test('does not play for a muted sender', () async {
      final container = makeContainer();
      container
          .read(notificationSettingsProvider.notifier)
          .muteParticipant('u-ada');

      await receive(container);

      expect(shown, isEmpty);
      expect(sound.plays, 0);
    });

    test('does not play for your own message', () async {
      final container = makeContainer();

      await receive(container, from: 'me');

      expect(shown, isEmpty);
      expect(sound.plays, 0);
    });

    test(
      'does not play when the notification preferences say nothing',
      () async {
        final container = makeContainer(
          preferences: _allowed.copyWith(mode: NotificationMode.none),
        );

        await receive(container);

        expect(shown, isEmpty);
        expect(sound.plays, 0);
      },
    );

    test('does not play when that conversation is open and focused', () async {
      final container = makeContainer();
      focused = true;
      container
          .read(selectedDmProvider.notifier)
          .select(
            DmConversation(
              channelId: 'c-ada',
              username: 'Ada',
              participantId: 'u-ada',
              previewMessage: '',
              unreadCount: 0,
            ),
          );

      await receive(container);

      expect(shown, isEmpty);
      expect(sound.plays, 0);
    });

    test(
      'plays once, not twice, for two quick messages from one sender',
      () async {
        final container = makeContainer();

        await receive(container);
        await receive(container);

        expect(shown, hasLength(1));
        expect(sound.plays, 1);
      },
    );

    test('does not play when the notification could not be shown', () async {
      show = (_) async => throw Exception('no notification support');
      final container = makeContainer();

      await receive(container);

      expect(sound.plays, 0);
    });
  });

  group('the message sound setting', () {
    test('is on by default', () {
      final container = makeContainer();

      expect(container.read(messageSoundEnabledProvider), isTrue);
    });

    test('is kept on this device for the signed-in user', () async {
      final storage = _MemoryStorage();
      if (locator.isRegistered<SecureStorageService>()) {
        locator.unregister<SecureStorageService>();
      }
      locator.registerSingleton<SecureStorageService>(storage);
      addTearDown(() => locator.unregister<SecureStorageService>());

      final first = makeContainer();
      first.read(messageSoundEnabledProvider.notifier).setEnabled(false);
      await Future<void>.delayed(Duration.zero);
      expect(storage.values['message_sound_me'], 'false');

      final second = makeContainer();
      expect(second.read(messageSoundEnabledProvider), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(second.read(messageSoundEnabledProvider), isFalse);

      second.read(messageSoundEnabledProvider.notifier).setEnabled(true);
      await Future<void>.delayed(Duration.zero);
      expect(storage.values['message_sound_me'], 'true');
    });

    test('a choice made while the saved one loads is not undone', () async {
      final storage = _MemoryStorage()..values['message_sound_me'] = 'false';
      if (locator.isRegistered<SecureStorageService>()) {
        locator.unregister<SecureStorageService>();
      }
      locator.registerSingleton<SecureStorageService>(storage);
      addTearDown(() => locator.unregister<SecureStorageService>());

      final container = makeContainer();
      expect(container.read(messageSoundEnabledProvider), isTrue);
      container.read(messageSoundEnabledProvider.notifier).setEnabled(true);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(messageSoundEnabledProvider), isTrue);
    });
  });
}
