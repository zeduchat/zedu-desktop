import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockDmRepository extends Mock implements DmRepository {}

void main() {
  late MockDmRepository mockRepo;

  setUp(() {
    mockRepo = MockDmRepository();
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
  });

  tearDown(() {
    if (locator.isRegistered<AppConfig>()) {
      locator.unregister<AppConfig>();
    }
  });

  group('DmListNotifier mock guard (#2581)', () {
    test(
      'returns empty list in production mode when API returns empty list',
      () async {
        locator.registerSingleton<AppConfig>(
          const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
        );

        when(
          () => mockRepo.getConversations(orgId: 'test-org', page: 1),
        ).thenAnswer((_) async => <DmConversation>[]);

        final container = ProviderContainer(
          overrides: [
            currentOrgIdProvider.overrideWithValue('test-org'),
            dmRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(dmListProvider.future);

        expect(result, isEmpty);
        verify(
          () => mockRepo.getConversations(orgId: 'test-org', page: 1),
        ).called(1);
      },
    );

    test(
      'injects mock conversation when usesMockData is true and API returns empty list',
      () async {
        locator.registerSingleton<AppConfig>(
          const AppConfig(apiBaseUrl: 'http://test', usesMockData: true),
        );

        when(
          () => mockRepo.getConversations(orgId: 'test-org', page: 1),
        ).thenAnswer((_) async => <DmConversation>[]);

        final container = ProviderContainer(
          overrides: [
            currentOrgIdProvider.overrideWithValue('test-org'),
            dmRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(dmListProvider.future);

        expect(result, isNotEmpty);
        expect(result.first.channelId, 'mock-channel-id-123');
        expect(result.first.username, 'Test User');
        expect(
          result.first.previewMessage,
          'This is a test conversation. Tap to test the composer.',
        );
      },
    );

    test(
      'returns actual conversations regardless of usesMockData setting',
      () async {
        locator.registerSingleton<AppConfig>(
          const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
        );

        final realConversation = DmConversation(
          channelId: 'channel-real-456',
          username: 'Real User',
          participantId: 'user-456',
          previewMessage: 'Hello there!',
          unreadCount: 2,
        );

        when(
          () => mockRepo.getConversations(orgId: 'test-org', page: 1),
        ).thenAnswer((_) async => [realConversation]);

        final container = ProviderContainer(
          overrides: [
            currentOrgIdProvider.overrideWithValue('test-org'),
            dmRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(dmListProvider.future);

        expect(result.length, 1);
        expect(result.first.channelId, 'channel-real-456');
        expect(result.first.username, 'Real User');
      },
    );
  });
}
