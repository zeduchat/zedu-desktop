import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _MockAppLinks extends Mock implements AppLinks {}

class _Workspace extends Notifier<String> {
  @override
  String build() => '';

  void select(String id) => state = id;
}

final _workspaceProvider = NotifierProvider<_Workspace, String>(_Workspace.new);

class _Credits extends CreditsNotifier {
  _Credits(this.verify);

  final Future<bool> Function(String, String) verify;

  @override
  CreditsState build() => const CreditsState();

  @override
  Future<bool> verifyPayment({
    required String sessionId,
    required String orgId,
  }) => verify(sessionId, orgId);
}

void main() {
  final link = Uri.parse('zedu://credits/payment-success?session_id=cs-1');
  late StreamController<Uri> links;
  late List<(String, String)> calls;

  setUp(() {
    links = StreamController<Uri>.broadcast();
    calls = [];
    locator.registerSingleton<AppConfig>(
      const AppConfig(
        apiBaseUrl: 'https://api.zedu.chat/api/v1/',
        usesMockData: false,
        webAppUrl: 'https://zedu.chat',
      ),
    );
  });

  tearDown(() async {
    await links.close();
    await locator.unregister<AppConfig>();
  });

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    String org = 'org-1',
    Uri? initialLink,
    Future<bool> Function()? verify,
  }) async {
    final appLinks = _MockAppLinks();
    when(() => appLinks.getInitialLink()).thenAnswer((_) async => initialLink);
    when(() => appLinks.uriLinkStream).thenAnswer((_) => links.stream);
    final container = ProviderContainer(
      overrides: [
        creditsOrgIdProvider.overrideWith(
          (ref) => ref.watch(_workspaceProvider),
        ),
        creditsNotifierProvider.overrideWith(
          () => _Credits((session, workspace) {
            calls.add((session, workspace));
            return verify?.call() ?? Future.value(false);
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(_workspaceProvider.notifier).select(org);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CreditsPaymentDeepLinkListener(
            appLinks: appLinks,
            child: const Scaffold(body: Text('Payment link test')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('verifies immediately when the workspace is ready', (
    tester,
  ) async {
    await mount(tester, initialLink: link);

    expect(calls, [('cs-1', 'org-1')]);
  });

  testWidgets('retains a cold-start link until the workspace becomes ready', (
    tester,
  ) async {
    final container = await mount(tester, org: '', initialLink: link);
    expect(calls, isEmpty);

    container.read(_workspaceProvider.notifier).select('org-restored');
    await tester.pumpAndSettle();

    expect(calls, [('cs-1', 'org-restored')]);
  });

  testWidgets('coalesces duplicate links waiting for a workspace', (
    tester,
  ) async {
    final container = await mount(tester, org: '', initialLink: link);
    links.add(link);
    links.add(link);
    await tester.pumpAndSettle();

    container.read(_workspaceProvider.notifier).select('org-restored');
    await tester.pumpAndSettle();

    expect(calls, [('cs-1', 'org-restored')]);
  });

  testWidgets('retains distinct sessions received before workspace readiness', (
    tester,
  ) async {
    final container = await mount(tester, org: '', initialLink: link);
    links.add(Uri.parse('zedu://credits/payment-success?session_id=cs-2'));
    await tester.pumpAndSettle();

    container.read(_workspaceProvider.notifier).select('org-restored');
    await tester.pumpAndSettle();

    expect(calls, [('cs-1', 'org-restored'), ('cs-2', 'org-restored')]);
  });

  testWidgets('verifies a payment link from the trusted web host', (
    tester,
  ) async {
    await mount(
      tester,
      initialLink: Uri.parse(
        'https://zedu.chat/credits/payment-success?session_id=cs-web',
      ),
    );

    expect(calls, [('cs-web', 'org-1')]);
  });

  testWidgets('does not verify a payment link from an untrusted host', (
    tester,
  ) async {
    await mount(
      tester,
      initialLink: Uri.parse(
        'https://evil.example/credits/payment-success?session_id=cs-evil',
      ),
    );
    links.add(
      Uri.parse(
        'https://zedu.chat.evil.example/credits/payment-success?session_id=cs-x',
      ),
    );
    links.add(
      Uri.parse('http://zedu.chat/credits/payment-success?session_id=cs-y'),
    );
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
  });

  testWidgets('allows redelivery after verification returns false', (
    tester,
  ) async {
    await mount(tester, initialLink: link);
    links.add(link);
    await tester.pumpAndSettle();

    expect(calls, [('cs-1', 'org-1'), ('cs-1', 'org-1')]);
  });

  testWidgets('suppresses in-flight duplicates and releases failed attempts', (
    tester,
  ) async {
    final pending = Completer<bool>();
    await mount(tester, verify: () => pending.future);
    links.add(link);
    await tester.pumpAndSettle();
    links.add(link);
    await tester.pumpAndSettle();
    final inFlightCalls = calls.length;

    pending.complete(false);
    await tester.pumpAndSettle();
    links.add(link);
    await tester.pumpAndSettle();

    expect(inFlightCalls, 1);
    expect(calls, [('cs-1', 'org-1'), ('cs-1', 'org-1')]);
  });

  testWidgets('allows retry after verification throws', (tester) async {
    var attempts = 0;
    await mount(
      tester,
      verify: () async {
        if (attempts++ == 0) throw StateError('Temporary verification failure');
        return false;
      },
    );
    links.add(link);
    await tester.pumpAndSettle();
    links.add(link);
    await tester.pumpAndSettle();

    expect(calls, [('cs-1', 'org-1'), ('cs-1', 'org-1')]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not reverify successful sessions after another link', (
    tester,
  ) async {
    await mount(tester, initialLink: link, verify: () async => true);
    links.add(Uri.parse('zedu://credits/payment-success?session_id=cs-2'));
    await tester.pumpAndSettle();
    links.add(link);
    await tester.pumpAndSettle();

    expect(calls, [('cs-1', 'org-1'), ('cs-2', 'org-1')]);
  });

  testWidgets('does not verify a pending link after the listener is removed', (
    tester,
  ) async {
    final container = await mount(tester, org: '', initialLink: link);
    await tester.pumpWidget(const SizedBox.shrink());
    container.read(_workspaceProvider.notifier).select('org-restored');
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
