import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeRepository implements BuzzMeetingsRepository {
  _FakeRepository(this.result);

  final Result<String> result;
  int calls = 0;

  @override
  Future<Result<String>> createMeeting() async {
    calls++;
    return result;
  }
}

const _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

Future<void> _pump(
  WidgetTester tester,
  _FakeRepository repository, {
  String slug = 'acme',
  bool signedIn = true,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        buzzMeetingsRepositoryProvider.overrideWithValue(repository),
        buzzOrgSlugProvider.overrideWithValue(slug),
        buzzSignedInProvider.overrideWithValue(signedIn),
        buzzConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'https://api.zedu.chat/api/v1/',
            usesMockData: false,
          ),
        ),
      ],
      child: buildTestMaterialApp(const Scaffold(body: BuzzView())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the Buzz page', (tester) async {
    await _pump(tester, _FakeRepository(const Success('abc')));

    expect(
      find.text(
        'Seamless video calls and meetings for every learning community.',
      ),
      findsOneWidget,
    );
    expect(find.text('New meeting'), findsOneWidget);
    expect(find.text('Enter a code or link'), findsOneWidget);
  });

  testWidgets('Join is enabled once a code is typed', (tester) async {
    await _pump(tester, _FakeRepository(const Success('abc')));

    TextButton join() =>
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Join'));
    expect(join().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'abc-defg-hij');
    await tester.pump();

    expect(join().onPressed, isNotNull);
  });

  testWidgets('a meeting for later shows its link to copy', (tester) async {
    final repository = _FakeRepository(const Success('abc-defg-hij'));
    await _pump(tester, repository);

    await tester.tap(find.text('New meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Start an instant meeting'), findsOneWidget);
    await tester.tap(find.text('Create a meeting for later'));
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(find.text("Here's the link to your meeting"), findsOneWidget);
    expect(
      find.text('https://zedu.chat/acme/buzz/abc-defg-hij'),
      findsOneWidget,
    );
    expect(find.byTooltip('Copy meeting link'), findsOneWidget);
  });

  group('Join', () {
    final launchedUrls = <String>[];

    setUp(() {
      launchedUrls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_urlLauncherChannel, (call) async {
            if (call.method == 'launch') {
              launchedUrls.add((call.arguments as Map)['url'] as String);
            }
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_urlLauncherChannel, null);
    });

    Future<void> join(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField), 'abc-defg-hij');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Join'));
      await tester.pump();
    }

    // AppToastService auto-dismisses on a 4s timer; let it fire before the
    // test ends so no timer is left pending.
    Future<void> drainToastTimer(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    }

    testWidgets('signed in with a workspace opens the meeting without a '
        'sign-in error', (tester) async {
      await _pump(tester, _FakeRepository(const Success('abc')));

      await join(tester);
      await tester.pumpAndSettle();

      expect(launchedUrls, ['https://zedu.chat/acme/buzz/abc-defg-hij']);
      expect(find.text('Sign in again to join a meeting.'), findsNothing);
    });

    testWidgets('signed in without a workspace slug explains the workspace '
        'is missing', (tester) async {
      await _pump(tester, _FakeRepository(const Success('abc')), slug: '');

      await join(tester);

      expect(
        find.text(BuzzMeetingsNotifier.workspaceMissingJoinMessage),
        findsOneWidget,
      );
      expect(find.text('Sign in again to join a meeting.'), findsNothing);
      expect(launchedUrls, isEmpty);
      await drainToastTimer(tester);
    });

    testWidgets('signed out asks to sign in again', (tester) async {
      await _pump(
        tester,
        _FakeRepository(const Success('abc')),
        slug: '',
        signedIn: false,
      );

      await join(tester);

      expect(find.text('Sign in again to join a meeting.'), findsOneWidget);
      expect(launchedUrls, isEmpty);
      await drainToastTimer(tester);
    });
  });
}
