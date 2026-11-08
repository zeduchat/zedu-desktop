import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _SignedOutAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

void main() {
  // LocalNotification registers its platform channel when it is created.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService handleIncomingMessage (Ziki #2717)', () {
    late ProviderContainer container;
    late List<LocalNotification> shown;

    setUp(() {
      shown = [];
      container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_SignedOutAuthNotifier.new),
          currentOrgIdProvider.overrideWithValue('org-1'),
          // No saved preferences: notifications are allowed.
          desktopNotificationPreferencesProvider.overrideWith(
            (ref) async => null,
          ),
          notificationServiceProvider.overrideWith(
            (ref) => NotificationService(
              ref,
              null,
              () async {},
              () async => false,
              (notification) async => shown.add(notification),
            ),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    Future<void> receive(Map<String, dynamic> message, String sender) =>
        container
            .read(notificationServiceProvider)
            .handleIncomingMessage(message, 'chat-1', sender);

    test('notifies for a message from a real sender', () async {
      await receive({'user_id': 'u-ada', 'content': 'Hi'}, 'Ada');

      expect(shown, hasLength(1));
      expect(shown.single.title, 'New DM from Ada');
      expect(shown.single.body, 'Hi');
    });

    test('reads the sender from userId too', () async {
      await receive({'userId': 'u-ada', 'content': 'Hi'}, 'Ada');

      expect(shown, hasLength(1));
    });

    test('does not notify for a message with no sender id', () async {
      await receive({'type': 'system', 'content': 'Ada joined'}, 'Someone');

      expect(shown, isEmpty);
    });

    test('does not notify for a blank sender id', () async {
      await receive({'user_id': '  ', 'content': 'Hi'}, 'Someone');
      await receive({'user_id': null, 'userId': null}, 'Someone');

      expect(shown, isEmpty);
    });

    test('a message with no sender does not hold back the next ones', () async {
      await receive({'content': 'event'}, 'Someone');
      await receive({'content': 'event'}, 'Someone');
      await receive({'user_id': 'u-ada', 'content': 'Hi'}, 'Ada');
      await receive({'user_id': 'u-bo', 'content': 'Hey'}, 'Bo');

      expect(shown.map((n) => n.title), ['New DM from Ada', 'New DM from Bo']);
    });

    test('still throttles one sender within five seconds', () async {
      await receive({'user_id': 'u-ada', 'content': 'one'}, 'Ada');
      await receive({'user_id': 'u-ada', 'content': 'two'}, 'Ada');

      expect(shown, hasLength(1));
    });
  });
}
