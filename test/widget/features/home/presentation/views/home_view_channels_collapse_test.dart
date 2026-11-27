import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

class _FakeCreditsNotifier extends CreditsNotifier {
  @override
  CreditsState build() => const CreditsState();

  @override
  Future<void> load({String? orgId}) async {}
}

class _FakeChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    Channel(
      id: 'c1',
      name: 'general',
      description: 'General talk',
      organisationId: 'org-1',
      ownerId: 'u1',
      membersCount: 1,
    ),
    Channel(
      id: 'c2',
      name: 'random',
      description: 'Random talk',
      organisationId: 'org-1',
      ownerId: 'u1',
      membersCount: 2,
    ),
  ];
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();
}

class _EmptyChannelRepository extends Mock implements ChannelRepository {
  @override
  Future<Result<ChannelMessagePage>> fetchChannelMessages(
    String id, {
    int page = 1,
  }) async => const Success(ChannelMessagePage(messages: [], hasMore: false));
}

class _FakeSecureStorageService extends Fake implements SecureStorageService {
  @override
  Future<String?> readData(String key) async => null;

  @override
  Future<void> writeData(String key, String value) async {}

  @override
  Future<void> deleteValue(String key) async {}

  @override
  Future<String?> getAccessToken() async => null;
}

void main() {
  setUp(() {
    locator.registerSingleton<SecureStorageService>(
      _FakeSecureStorageService(),
    );
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: 'http://test/', usesMockData: false),
    );
    addTearDown(locator.reset);
  });

  Future<ProviderContainer> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          creditsNotifierProvider.overrideWith(_FakeCreditsNotifier.new),
          channelProvider.overrideWith(_FakeChannelNotifier.new),
          userProfileNotifierProvider.overrideWith(
            _FakeUserProfileNotifier.new,
          ),
          channelRepositoryProvider.overrideWithValue(
            _EmptyChannelRepository(),
          ),
        ],
        child: buildTestMaterialApp(const HomeView()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(HomeView)));
  }

  testWidgets('the Channels header collapses and expands the channel list', (
    tester,
  ) async {
    await pumpHome(tester);
    final toggle = find.byKey(const Key('home-channels-section-toggle'));
    final chevron = find.descendant(of: toggle, matching: find.byType(Icon));

    expect(find.byType(SidebarChannelList), findsOneWidget);
    expect(find.text('View all channels'), findsOneWidget);
    expect(tester.widget<Icon>(chevron).icon, Icons.arrow_drop_down);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.byType(SidebarChannelList), findsNothing);
    expect(find.text('View all channels'), findsNothing);
    expect(find.text('Add channel'), findsNothing);
    expect(tester.widget<Icon>(chevron).icon, Icons.arrow_right);
    // The rest of the sidebar stays.
    expect(find.byType(SidebarDmSection), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.byType(SidebarChannelList), findsOneWidget);
    expect(find.text('View all channels'), findsOneWidget);
    expect(find.text('Add channel'), findsOneWidget);
    expect(tester.widget<Icon>(chevron).icon, Icons.arrow_drop_down);
  });
}
