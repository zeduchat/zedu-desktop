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

class _EmptyChannelRepository extends Mock implements ChannelRepository {}

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

  Future<void> pumpHome(WidgetTester tester) async {
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
  }

  testWidgets('View all channels opens the Channel Directory', (tester) async {
    await pumpHome(tester);
    expect(find.text('Channel Directory'), findsNothing);

    await tester.tap(find.text('View all channels'));
    await tester.pumpAndSettle();
    expect(find.text('Channel Directory'), findsOneWidget);

    await tester.tap(find.text('Random talk'));
    await tester.pumpAndSettle();
    expect(find.text('Channel Directory'), findsNothing);
    expect(find.text('Welcome to #random'), findsOneWidget);
  });

  testWidgets('View all channels is readable and has a visible hover state', (
    tester,
  ) async {
    await pumpHome(tester);

    final inkWellFinder = find.ancestor(
      of: find.text('View all channels'),
      matching: find.byType(InkWell),
    );
    expect(inkWellFinder, findsOneWidget);

    final inkWell = tester.widget<InkWell>(inkWellFinder);
    final material = tester.widget<Material>(
      find.ancestor(of: inkWellFinder, matching: find.byType(Material)).first,
    );
    final text = tester.widget<Text>(find.text('View all channels'));

    const palette = AppPalette.light;
    expect(text.style?.color, palette.onPrimary);
    expect(material.color?.a, moreOrLessEquals(0.12));
    expect(
      (material.shape! as RoundedRectangleBorder).side.color.a,
      greaterThanOrEqualTo(0.45),
    );
    expect(inkWell.onTap, isNotNull);
    expect(inkWell.hoverColor, isNotNull);
    expect(inkWell.hoverColor!.a, greaterThanOrEqualTo(0.2));
  });
}
