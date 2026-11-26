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

  testWidgets('the Channels heading collapses and expands the section', (
    tester,
  ) async {
    await pumpHome(tester);
    final sidebar = find.byType(SidebarChannelList);
    expect(sidebar, findsOneWidget);
    expect(find.text('View all channels'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsWidgets);

    await tester.tap(find.text('Channels'));
    await tester.pumpAndSettle();
    expect(sidebar, findsNothing);
    expect(find.text('View all channels'), findsNothing);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Channels'),
          matching: find.byType(InkWell),
        ),
        matching: find.byIcon(Icons.arrow_right),
      ),
      findsOneWidget,
    );
    // The Direct messages section stays put.
    expect(find.text('Direct messages'), findsOneWidget);

    await tester.tap(find.text('Channels'));
    await tester.pumpAndSettle();
    expect(sidebar, findsOneWidget);
    expect(find.text('View all channels'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Channels'),
          matching: find.byType(InkWell),
        ),
        matching: find.byIcon(Icons.arrow_drop_down),
      ),
      findsOneWidget,
    );
  });
}
