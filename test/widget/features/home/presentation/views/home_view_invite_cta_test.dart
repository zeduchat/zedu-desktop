import 'dart:io';

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

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

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(
      id: 'org1',
      name: 'Test Workspace',
      avatar: '',
    ),
  );
}

class _FakeSecureStorageService extends Fake implements SecureStorageService {
  @override
  Future<String?> readData(String key) async => null;

  @override
  Future<void> writeData(String key, String value) async {}

  @override
  Future<void> deleteValue(String key) async {}
}

class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile, {this.tolerance = 0.05});

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    final passed = result.passed || result.diffPercent <= tolerance;
    if (passed) {
      result.dispose();
      return true;
    }

    final String error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

class _FakeChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    Channel(
      id: '1',
      name: 'general',
      description: 'General talk',
      organisationId: 'org1',
      ownerId: 'u1',
      membersCount: 1,
    ),
  ];
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  final invitedEmails = <String>[];
  int generatedLinkCount = 0;

  @override
  UserProfileState build() => const UserProfileState();

  @override
  Future<List<Map<String, dynamic>>> fetchRegisteredUsers() async => [];

  @override
  Future<String?> generateInviteLink() async {
    generatedLinkCount++;
    return 'https://example.com/invite';
  }

  @override
  Future<void> inviteMember({
    required String email,
    required String role,
    String? userId,
  }) async {
    invitedEmails.add(email);
  }
}

Widget _buildHomeView(_FakeUserProfileNotifier userProfileNotifier) {
  final buttonStyle = AppTheme.light.elevatedButtonTheme.style!;
  final homeTheme = AppTheme.light.copyWith(
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: buttonStyle.copyWith(
        textStyle: WidgetStatePropertyAll(
          buttonStyle.textStyle!
              .resolve({})!
              .copyWith(fontFamily: FontFamily.lato),
        ),
      ),
    ),
  );

  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
      creditsNotifierProvider.overrideWith(_FakeCreditsNotifier.new),
      channelProvider.overrideWith(_FakeChannelNotifier.new),
      channelHistoryProvider.overrideWith(
        (ref, channelId) async => <ChannelMessage>[],
      ),
      workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
      userProfileNotifierProvider.overrideWith(() => userProfileNotifier),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: homeTheme,
      home: const HomeView(),
    ),
  );
}

Future<void> _pumpHomeView(
  WidgetTester tester,
  Size size, {
  _FakeUserProfileNotifier? userProfileNotifier,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _buildHomeView(userProfileNotifier ?? _FakeUserProfileNotifier()),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

Finder get _inviteButton =>
    find.widgetWithText(ElevatedButton, 'Invite teammates');

Finder get _emailField => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      widget.decoration?.hintText?.contains('Enter name or email') == true,
);

Future<void> _loadAppFonts() async {
  if (!locator.isRegistered<SecureStorageService>()) {
    locator.registerSingleton<SecureStorageService>(
      _FakeSecureStorageService(),
    );
  }
  if (!locator.isRegistered<AppConfig>()) {
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
    );
  }

  for (final family in ['Lato', 'Roboto']) {
    final loader = FontLoader(family);
    for (final weight in ['Regular', 'Bold']) {
      final bytes = File('assets/fonts/$family/$family-$weight.ttf');
      if (bytes.existsSync()) {
        loader.addFont(
          Future.value(ByteData.sublistView(bytes.readAsBytesSync())),
        );
      }
    }
    await loader.load();
  }
  var flutterRoot = File(Platform.resolvedExecutable).parent;
  File? iconFont;
  while (flutterRoot.path != flutterRoot.parent.path) {
    for (final name in [
      'MaterialIcons-Regular.otf',
      'materialicons-regular.otf',
    ]) {
      final candidate = File(
        [
          flutterRoot.path,
          'bin',
          'cache',
          'artifacts',
          'material_fonts',
          name,
        ].join(Platform.pathSeparator),
      );
      if (candidate.existsSync()) {
        iconFont = candidate;
        break;
      }
    }
    if (iconFont != null) break;
    flutterRoot = flutterRoot.parent;
  }
  if (iconFont == null || !iconFont.existsSync()) {
    throw StateError('Flutter Material Icons font was not found.');
  }
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(iconFont.readAsBytesSync())));
  await iconLoader.load();
  final poetsenFile = File('assets/fonts/Lato/Lato-Regular.ttf');
  if (poetsenFile.existsSync()) {
    final wordmarkLoader = FontLoader('Poetsen One')
      ..addFont(
        Future.value(ByteData.sublistView(poetsenFile.readAsBytesSync())),
      );
    await wordmarkLoader.load();
  }

  final currentComparator = goldenFileComparator;
  if (currentComparator is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenComparator(
      currentComparator.basedir.resolve('home_view_invite_cta_test.dart'),
      tolerance: 0.05,
    );
  }
}

void main() {
  setUpAll(_loadAppFonts);

  group('HomeView invite onboarding CTA', () {
    testWidgets('shows the approved invitation copy and accessible CTA', (
      tester,
    ) async {
      await _pumpHomeView(tester, const Size(1280, 720));

      expect(find.text('Bring your team into Zedu'), findsOneWidget);
      expect(
        find.text('Invite teammates to join #general and start collaborating.'),
        findsOneWidget,
      );
      expect(_inviteButton, findsOneWidget);

      final semanticsHandle = tester.ensureSemantics();
      final semantics = tester.getSemantics(_inviteButton).getSemanticsData();
      semanticsHandle.dispose();
      expect(semantics.label, 'Invite teammates');
      expect(semantics.hasAction(SemanticsAction.tap), isTrue);
      expect(semantics.flagsCollection.isButton, isTrue);

      final buttonStyle = tester.widget<ElevatedButton>(_inviteButton).style!;
      expect(
        buttonStyle.side!.resolve({WidgetState.focused})!.color,
        AppPalette.light.borderOutline,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens the existing invitation modal from the CTA', (
      tester,
    ) async {
      await _pumpHomeView(tester, const Size(1280, 720));

      await tester.tap(_inviteButton);
      await tester.pumpAndSettle();

      expect(find.byType(InviteTeammatesModal), findsOneWidget);
      expect(find.text('Add people to #general'), findsOneWidget);
      expect(_emailField, findsOneWidget);
      expect(find.byTooltip('Copy Invite Link'), findsOneWidget);
    });

    testWidgets('captures the redesigned empty-channel screen', (tester) async {
      await _pumpHomeView(tester, const Size(1280, 720));

      await expectLater(
        find.byType(HomeView),
        matchesGoldenFile('goldens/home_view_invite_cta.png'),
      );
    });

    testWidgets('captures the open invitation modal', (tester) async {
      await _pumpHomeView(tester, const Size(1280, 720));
      await tester.tap(_inviteButton);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Overlay).last,
        matchesGoldenFile('goldens/home_view_invite_modal.png'),
      );
    });

    testWidgets('closes the invitation modal using its accessible button', (
      tester,
    ) async {
      await _pumpHomeView(tester, const Size(1280, 720));
      await tester.tap(_inviteButton);
      await tester.pumpAndSettle();

      final closeButton = find.byTooltip('Close invitation dialog');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.byType(InviteTeammatesModal), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('preserves email invitations through the existing modal', (
      tester,
    ) async {
      const email = 'teammate@example.com';
      final userProfileNotifier = _FakeUserProfileNotifier();
      await _pumpHomeView(
        tester,
        const Size(1280, 720),
        userProfileNotifier: userProfileNotifier,
      );

      await tester.tap(_inviteButton);
      await tester.pumpAndSettle();
      await tester.enterText(_emailField, email);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(userProfileNotifier.invitedEmails, [email]);
      expect(find.byType(InviteTeammatesModal), findsNothing);
    });

    testWidgets('preserves the existing shareable invitation-link action', (
      tester,
    ) async {
      final userProfileNotifier = _FakeUserProfileNotifier();
      await _pumpHomeView(
        tester,
        const Size(1280, 720),
        userProfileNotifier: userProfileNotifier,
      );
      String? copiedLink;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedLink =
                (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.tap(_inviteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Copy Invite Link'));
      await tester.pumpAndSettle();

      expect(userProfileNotifier.generatedLinkCount, 1);
      expect(copiedLink, 'https://example.com/invite');
    });

    testWidgets('keeps the CTA within the card at compact desktop size', (
      tester,
    ) async {
      await _pumpHomeView(tester, const Size(1280, 600), settle: false);

      final card = find.ancestor(
        of: find.text('Bring your team into Zedu'),
        matching: find.byType(Card),
      );
      final cardRect = tester.getRect(card);
      final buttonRect = tester.getRect(_inviteButton);

      expect(buttonRect.left, greaterThanOrEqualTo(cardRect.left));
      expect(buttonRect.right, lessThanOrEqualTo(cardRect.right));
      expect(buttonRect.bottom, lessThanOrEqualTo(cardRect.bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the CTA visible at narrow desktop widths', (
      tester,
    ) async {
      await _pumpHomeView(tester, const Size(1100, 600));

      expect(find.text('Bring your team into Zedu'), findsOneWidget);
      expect(_inviteButton, findsOneWidget);

      final card = find.ancestor(
        of: find.text('Bring your team into Zedu'),
        matching: find.byType(Card),
      );
      final cardRect = tester.getRect(card);
      final buttonRect = tester.getRect(_inviteButton);

      expect(buttonRect.left, greaterThanOrEqualTo(cardRect.left));
      expect(buttonRect.right, lessThanOrEqualTo(cardRect.right));
      expect(buttonRect.bottom, lessThanOrEqualTo(cardRect.bottom));
      expect(tester.takeException(), isNull);
    });
  });
}
