import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockNotificationService extends Mock implements NotificationService {}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'user-1',
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      phone: '',
      username: 'testuser',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'org-slug',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

class _FakeDmListNotifier extends DmListNotifier {
  @override
  Future<List<DmConversation>> build() async => [
    DmConversation(
      channelId: 'ch-1',
      username: 'Ada',
      participantId: 'user-2',
      previewMessage: '',
      unreadCount: 0,
    ),
  ];
}

Map<String, dynamic> _message(String id, {String userId = 'user-2'}) => {
  'id': id,
  'user_id': userId,
  'username': 'Ada',
  'content': 'message $id',
};

void main() {
  testWidgets(
    'the first poll primes history without notifying, later polls notify '
    'only new messages (#2979)',
    (tester) async {
      final repo = _MockDmRepository();
      final notifications = _MockNotificationService();
      var page = [_message('m1'), _message('m2'), _message('m3')];
      when(
        () => repo.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer((_) async => page);
      when(
        () => notifications.handleIncomingMessage(any(), any(), any()),
      ).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          dmRepositoryProvider.overrideWithValue(repo),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          dmListProvider.overrideWith(_FakeDmListNotifier.new),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
      );
      final listSub = container.listen(dmListProvider, (_, _) {});
      final sub = container.listen(dmNotificationPollerProvider, (_, _) {});
      await tester.pump();

      // First tick: three old messages, no pop-ups.
      await tester.pump(const Duration(seconds: 10));
      verify(() => repo.getMessages('ch-1', page: 1)).called(1);
      verifyNever(
        () => notifications.handleIncomingMessage(any(), any(), any()),
      );

      // Second tick: one new message arrives and notifies exactly once.
      page = [_message('m4'), ...page];
      await tester.pump(const Duration(seconds: 10));
      final captured = verify(
        () => notifications.handleIncomingMessage(captureAny(), 'ch-1', 'Ada'),
      ).captured;
      expect(captured, hasLength(1));
      expect((captured.single as Map<String, dynamic>)['id'], 'm4');

      // Third tick with nothing new: still no further notifications.
      await tester.pump(const Duration(seconds: 10));
      verifyNever(
        () => notifications.handleIncomingMessage(any(), any(), any()),
      );

      sub.close();
      listSub.close();
      container.dispose();
    },
  );
}
