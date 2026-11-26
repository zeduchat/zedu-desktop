import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

const _config = AppConfig(
  apiBaseUrl: 'https://api.zedu.chat/api/v1/',
  usesMockData: false,
);

Channel _channel(String name) => Channel(
  id: 'channel-$name',
  name: name,
  description: '',
  organisationId: 'org-1',
  ownerId: 'user-1',
);

class _FakeChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [_channel('general')];
}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Workspace A', avatar: ''),
  );
}

class _EmptyChannelRepository extends Mock implements ChannelRepository {
  @override
  Future<Result<ChannelMessagePage>> fetchChannelMessages(
    String id, {
    int page = 1,
  }) async => const Success(ChannelMessagePage(messages: [], hasMore: false));

  @override
  Future<Result<List<DmParticipant>>> fetchChannelMembers(String id) async =>
      const Success(<DmParticipant>[]);
}

class _FakeSecureStorageService extends Fake implements SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<String?> readData(String key) async => _values[key];

  @override
  Future<void> writeData(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> deleteValue(String key) async => _values.remove(key);
}

/// Answers createMeeting with [result], or waits for [pending] when set.
class _FakeBuzzRepository implements BuzzMeetingsRepository {
  _FakeBuzzRepository(this.result);

  final Result<String> result;
  Completer<Result<String>>? pending;
  int calls = 0;

  @override
  Future<Result<String>> createMeeting() {
    calls++;
    return pending?.future ?? Future.value(result);
  }
}

/// Records the links the app asks the browser to open.
class _FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  _FakeUrlLauncher({this.opens = true});

  final bool opens;
  final launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return opens;
  }
}

String _directJoinLink(String code) => buzzMeetingUrl(
  webBaseUrl: _config.webBaseUrl,
  orgSlug: 'acme',
  code: code,
  directJoin: true,
).toString();

Finder get _startBuzz =>
    find.byKey(const ValueKey('channel_header_start_buzz'));

Future<_FakeUrlLauncher> _pump(
  WidgetTester tester,
  _FakeBuzzRepository repository, {
  bool browserOpens = true,
}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final launcher = _FakeUrlLauncher(opens: browserOpens);
  final originalLauncher = UrlLauncherPlatform.instance;
  UrlLauncherPlatform.instance = launcher;
  addTearDown(() => UrlLauncherPlatform.instance = originalLauncher);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        channelProvider.overrideWith(_FakeChannelNotifier.new),
        workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
        channelRepositoryProvider.overrideWithValue(_EmptyChannelRepository()),
        dmDraftStoreProvider.overrideWith(
          (ref) => DmDraftStore(
            _FakeSecureStorageService(),
            userId: 'user-1',
            orgId: 'org-1',
          ),
        ),
        buzzMeetingsRepositoryProvider.overrideWithValue(repository),
        buzzOrgSlugProvider.overrideWithValue('acme'),
        buzzConfigProvider.overrideWithValue(_config),
      ],
      child: buildTestMaterialApp(const Scaffold(body: HomeChatArea())),
    ),
  );
  await tester.pumpAndSettle();
  return launcher;
}

/// Lets a toast's dismiss timer fire before the test ends.
Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  group('channel header Start Buzz (Ziki #3054)', () {
    testWidgets('starts a meeting and opens it in the browser', (tester) async {
      final repository = _FakeBuzzRepository(const Success('abc-defg-hij'));
      final launcher = await _pump(tester, repository);

      expect(find.text('Start Buzz'), findsOneWidget);
      await tester.tap(_startBuzz);
      await tester.pumpAndSettle();

      expect(repository.calls, 1);
      expect(launcher.launched, [_directJoinLink('abc-defg-hij')]);
      expect(find.text('Start Buzz'), findsOneWidget);
    });

    testWidgets('a failed meeting shows the error and opens nothing', (
      tester,
    ) async {
      final repository = _FakeBuzzRepository(
        const Failure(ApiFailure(message: 'server down')),
      );
      final launcher = await _pump(tester, repository);

      await tester.tap(_startBuzz);
      await tester.pump();

      expect(repository.calls, 1);
      expect(launcher.launched, isEmpty);
      expect(
        find.text('Failed to create meeting. Please try again.'),
        findsOneWidget,
      );
      await _settleToast(tester);
    });

    testWidgets('says so when the browser cannot open the meeting', (
      tester,
    ) async {
      final repository = _FakeBuzzRepository(const Success('abc-defg-hij'));
      final launcher = await _pump(tester, repository, browserOpens: false);

      await tester.tap(_startBuzz);
      await tester.pump();

      expect(launcher.launched, hasLength(1));
      expect(
        find.text("Couldn't open the meeting in your browser."),
        findsOneWidget,
      );
      await _settleToast(tester);
    });

    testWidgets('shows Starting… and ignores taps while the meeting is made', (
      tester,
    ) async {
      final repository = _FakeBuzzRepository(const Success('abc-defg-hij'))
        ..pending = Completer<Result<String>>();
      final launcher = await _pump(tester, repository);

      await tester.tap(_startBuzz);
      await tester.pump();

      expect(find.text('Starting…'), findsOneWidget);
      expect(find.text('Start Buzz'), findsNothing);

      await tester.tap(_startBuzz);
      await tester.pump();
      expect(repository.calls, 1);

      repository.pending!.complete(const Success('abc-defg-hij'));
      await tester.pumpAndSettle();

      expect(repository.calls, 1);
      expect(launcher.launched, [_directJoinLink('abc-defg-hij')]);
      expect(find.text('Start Buzz'), findsOneWidget);
    });
  });
}
