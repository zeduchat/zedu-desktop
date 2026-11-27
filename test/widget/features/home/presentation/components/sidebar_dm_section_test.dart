import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

final _me = User(
  id: 'me',
  firstName: 'Dave',
  lastName: 'Tolu',
  email: 'me@zedu.chat',
  phone: '',
  username: 'me',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026, 10, 16),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'org-1',
  avatarUrl: '',
  defaultAvatarUrl: '',
);

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: _me);
}

class _FakeDmListNotifier extends DmListNotifier {
  _FakeDmListNotifier(this._conversations);

  final List<DmConversation> _conversations;

  @override
  Future<List<DmConversation>> build() async => _conversations;
}

class _LoadingDmListNotifier extends DmListNotifier {
  @override
  Future<List<DmConversation>> build() =>
      Completer<List<DmConversation>>().future;
}

class _FailingDmListNotifier extends DmListNotifier {
  @override
  Future<List<DmConversation>> build() async => throw Exception('offline');
}

/// The real notifier follows the selected workspace, which loads from the API.
class _FakeActiveChatNotifier extends ActiveChatNotifier {
  @override
  ActiveChatState build() => ActiveChatState.generalChannel;
}

class _FakeActionsNotifier extends DmConversationActionsNotifier {
  _FakeActionsNotifier(this._actions);

  final DmConversationActions _actions;

  @override
  DmConversationActions build() => _actions;
}

DmConversation _dm(
  String channelId,
  String username, {
  String? participantId,
  DateTime? lastReadAt,
}) {
  return DmConversation(
    channelId: channelId,
    username: username,
    participantId: participantId ?? 'user-$channelId',
    lastReadAt: lastReadAt,
    previewMessage: '',
    unreadCount: 0,
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  DmListNotifier Function()? dms,
  DmConversationActions actions = const DmConversationActions(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        activeChatProvider.overrideWith(_FakeActiveChatNotifier.new),
        // The selected DM follows the workspace, which loads from the API.
        currentOrgIdProvider.overrideWithValue('org-1'),
        dmListProvider.overrideWith(dms ?? () => _FakeDmListNotifier(const [])),
        dmConversationActionsProvider.overrideWith(
          () => _FakeActionsNotifier(actions),
        ),
      ],
      // A failed load would otherwise schedule retries that outlive the test.
      retry: (_, _) => null,
      child: buildTestMaterialApp(
        const Scaffold(body: SizedBox(width: 280, child: SidebarDmSection())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(
    tester.element(find.byType(SidebarDmSection)),
  );
}

void main() {
  final older = DateTime(2026, 11, 1);
  final newer = DateTime(2026, 11, 3);

  testWidgets('shows the Direct messages heading', (tester) async {
    await _pump(tester);

    expect(find.text('Direct messages'), findsOneWidget);
  });

  testWidgets('lists your own space first as "[Name] (you)"', (tester) async {
    await _pump(
      tester,
      dms: () => _FakeDmListNotifier([
        _dm('c-1', 'Ada Okafor', lastReadAt: newer),
        _dm('c-me', 'Dave Tolu', participantId: 'me', lastReadAt: older),
        _dm('c-2', 'Bola Ige', lastReadAt: older),
      ]),
    );

    expect(find.text('Dave Tolu (you)'), findsOneWidget);
    final ownTop = tester.getTopLeft(find.text('Dave Tolu (you)')).dy;
    final adaTop = tester.getTopLeft(find.text('Ada Okafor')).dy;
    final bolaTop = tester.getTopLeft(find.text('Bola Ige')).dy;
    expect(ownTop, lessThan(adaTop));
    expect(adaTop, lessThan(bolaTop));
  });

  testWidgets('orders other DMs like the DMs tab: pinned, then most recent', (
    tester,
  ) async {
    await _pump(
      tester,
      dms: () => _FakeDmListNotifier([
        _dm('c-1', 'Ada Okafor', lastReadAt: newer),
        _dm('c-2', 'Bola Ige', lastReadAt: older),
        _dm('c-3', 'Chidi Eze', lastReadAt: older),
      ]),
      actions: const DmConversationActions(
        pinnedIds: {'c-3'},
        deletedIds: {'c-2'},
      ),
    );

    expect(find.text('Bola Ige'), findsNothing);
    final chidiTop = tester.getTopLeft(find.text('Chidi Eze')).dy;
    final adaTop = tester.getTopLeft(find.text('Ada Okafor')).dy;
    expect(chidiTop, lessThan(adaTop));
  });

  testWidgets('selecting a DM opens it in the DMs tab', (tester) async {
    final ada = _dm('c-1', 'Ada Okafor', lastReadAt: newer);
    final container = await _pump(
      tester,
      dms: () => _FakeDmListNotifier([ada]),
    );

    await tester.tap(find.text('Ada Okafor'));
    await tester.pump();

    expect(container.read(selectedDmProvider)?.channelId, 'c-1');
    expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
  });

  testWidgets('shows an empty message when there are no DMs', (tester) async {
    await _pump(tester);

    expect(find.text('No direct messages yet'), findsOneWidget);
  });

  testWidgets('shows a loading message while DMs load', (tester) async {
    await _pump(tester, dms: _LoadingDmListNotifier.new);

    expect(find.text('Loading direct messages…'), findsOneWidget);
  });

  testWidgets('shows an error message when DMs fail to load', (tester) async {
    await _pump(tester, dms: _FailingDmListNotifier.new);

    expect(find.text("Couldn't load direct messages"), findsOneWidget);
  });

  group('compose button', () {
    testWidgets(
      'sits beside the heading with a New message tooltip and label',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await _pump(tester);

          final button = find.widgetWithIcon(IconButton, Icons.edit_note);
          expect(button, findsOneWidget);
          expect(tester.widget<IconButton>(button).tooltip, 'New message');
          expect(find.bySemanticsLabel('New message'), findsOneWidget);

          final headingCentre = tester.getCenter(find.text('Direct messages'));
          final buttonCentre = tester.getCenter(button);
          expect((buttonCentre.dy - headingCentre.dy).abs(), lessThan(12));
          expect(buttonCentre.dx, greaterThan(headingCentre.dx));
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets('opens the existing new-message flow and keeps Home', (
      tester,
    ) async {
      final ada = _dm('c-1', 'Ada Okafor', lastReadAt: newer);
      final container = await _pump(
        tester,
        dms: () => _FakeDmListNotifier([ada]),
      );
      container.read(selectedDmProvider.notifier).select(ada);

      await tester.tap(find.byTooltip('New message'));
      await tester.pump();

      expect(container.read(activeChatProvider), ActiveChatState.newGroupChat);
      expect(container.read(selectedDmProvider), isNull);
      expect(container.read(homeSidebarProvider), HomeSidebarType.home);
      expect(find.text('Direct messages'), findsOneWidget);
      expect(find.text('Ada Okafor'), findsOneWidget);
    });

    testWidgets('the section still works after closing the new-message flow', (
      tester,
    ) async {
      final ada = _dm('c-1', 'Ada Okafor', lastReadAt: newer);
      final container = await _pump(
        tester,
        dms: () => _FakeDmListNotifier([ada]),
      );

      await tester.tap(find.byTooltip('New message'));
      await tester.pump();
      // Closing the page picks a channel again, as the Home view does.
      container.read(activeChatProvider.notifier).selectChannel('general');
      await tester.pump();

      await tester.tap(find.text('Ada Okafor'));
      await tester.pump();

      expect(container.read(selectedDmProvider)?.channelId, 'c-1');
      expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
    });
  });

  testWidgets('a new message moves its conversation to the top (#12395)', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      dms: () => _FakeDmListNotifier([
        _dm('c-1', 'Ada Okafor', lastReadAt: newer),
        _dm('c-2', 'Bola Ige', lastReadAt: older),
      ]),
    );
    expect(
      tester.getTopLeft(find.text('Ada Okafor')).dy,
      lessThan(tester.getTopLeft(find.text('Bola Ige')).dy),
    );

    container.read(dmListProvider.notifier).recordIncomingMessage('c-2', {
      'id': 'm1',
      'user_id': 'user-c-2',
      'content': 'Are you there?',
      'created_at': DateTime(2026, 11, 4).toUtc().toIso8601String(),
    });
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('Bola Ige')).dy,
      lessThan(tester.getTopLeft(find.text('Ada Okafor')).dy),
    );
  });
}
