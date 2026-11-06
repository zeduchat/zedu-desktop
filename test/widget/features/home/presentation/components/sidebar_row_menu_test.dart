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

class _Auth extends AuthNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: _me);
}

class _Workspace extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState();

  @override
  Future<void> fetchWorkspaces() async {}
}

class _Channels extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    Channel(
      id: 'c-general',
      name: 'general',
      description: '',
      organisationId: '',
      ownerId: 'owner',
    ),
  ];
}

class _Dms extends DmListNotifier {
  @override
  Future<List<DmConversation>> build() async => [
    DmConversation(
      channelId: 'c-ada',
      username: 'Ada Okafor',
      participantId: 'p-ada',
      previewMessage: '',
      unreadCount: 0,
    ),
  ];
}

class _ActiveChat extends ActiveChatNotifier {
  @override
  ActiveChatState build() => ActiveChatState.generalChannel;
}

/// Pins and deletes without the preferences store or the server.
class _Actions extends DmConversationActionsNotifier {
  _Actions({this.deleteWorks = true});

  final bool deleteWorks;
  final deleted = <String>[];

  @override
  DmConversationActions build() => const DmConversationActions();

  @override
  void togglePinned(String channelId) {
    final ids = Set<String>.from(state.pinnedIds);
    ids.contains(channelId) ? ids.remove(channelId) : ids.add(channelId);
    state = state.copyWith(pinnedIds: ids);
  }

  @override
  Future<bool> delete(String channelId) async {
    deleted.add(channelId);
    return deleteWorks;
  }
}

/// Mutes without the settings storage.
class _Settings extends NotificationSettingsNotifier {
  @override
  NotificationSettings build() => const NotificationSettings();

  @override
  void muteParticipant(String participantId) {
    state = state.copyWith(
      mutedParticipantIds: {...state.mutedParticipantIds, participantId},
    );
  }

  @override
  void unmuteParticipant(String participantId) {
    state = state.copyWith(
      mutedParticipantIds: {...state.mutedParticipantIds}
        ..remove(participantId),
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  _Actions? actions,
}) async {
  final fakeActions = actions ?? _Actions();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_Auth.new),
        workspaceProvider.overrideWith(_Workspace.new),
        channelProvider.overrideWith(_Channels.new),
        dmListProvider.overrideWith(_Dms.new),
        activeChatProvider.overrideWith(_ActiveChat.new),
        dmConversationActionsProvider.overrideWith(() => fakeActions),
        notificationSettingsProvider.overrideWith(_Settings.new),
      ],
      retry: (_, _) => null,
      child: buildTestMaterialApp(
        const Scaffold(
          body: SizedBox(
            width: 280,
            child: Column(children: [SidebarChannelList(), SidebarDmSection()]),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(SidebarChannelList)),
  );
}

Future<void> _rightClick(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(
    tester.getCenter(target),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('right-click on a channel', () {
    testWidgets('offers Archive channel and Leave channel', (tester) async {
      await _pump(tester);

      await _rightClick(tester, find.text('general'));

      expect(find.text('Archive channel'), findsOneWidget);
      expect(find.text('Leave channel'), findsOneWidget);
    });

    testWidgets('Leave channel asks first, and Cancel leaves it alone', (
      tester,
    ) async {
      await _pump(tester);
      await _rightClick(tester, find.text('general'));

      await tester.tap(find.text('Leave channel'));
      await tester.pumpAndSettle();

      expect(find.text('Leave #general?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Leave #general?'), findsNothing);
      expect(find.text('general'), findsOneWidget);
    });

    testWidgets('Archive channel asks first', (tester) async {
      await _pump(tester);
      await _rightClick(tester, find.text('general'));

      await tester.tap(find.text('Archive channel'));
      await tester.pumpAndSettle();

      expect(find.text('Archive #general?'), findsOneWidget);
    });

    testWidgets('a left click still opens the channel and no menu', (
      tester,
    ) async {
      final container = await _pump(tester);

      await tester.tap(find.text('general'));
      await tester.pumpAndSettle();

      expect(find.text('Leave channel'), findsNothing);
      expect(container.read(activeChatProvider).id, 'general');
    });
  });

  group('right-click on a direct message', () {
    testWidgets('offers Pin, Mute and Delete', (tester) async {
      await _pump(tester);

      await _rightClick(tester, find.text('Ada Okafor'));

      expect(find.text('Pin conversation'), findsOneWidget);
      expect(find.text('Mute notifications'), findsOneWidget);
      expect(find.text('Delete conversation'), findsOneWidget);
    });

    testWidgets('Pin conversation pins it, and the menu then says Unpin', (
      tester,
    ) async {
      final container = await _pump(tester);
      await _rightClick(tester, find.text('Ada Okafor'));

      await tester.tap(find.text('Pin conversation'));
      await tester.pumpAndSettle();

      expect(
        container.read(dmConversationActionsProvider).pinnedIds,
        contains('c-ada'),
      );
      await _rightClick(tester, find.text('Ada Okafor'));
      expect(find.text('Unpin conversation'), findsOneWidget);
    });

    testWidgets('Mute notifications mutes the person, and the menu then says '
        'Unmute', (tester) async {
      final container = await _pump(tester);
      await _rightClick(tester, find.text('Ada Okafor'));

      await tester.tap(find.text('Mute notifications'));
      await tester.pumpAndSettle();

      expect(
        container.read(notificationSettingsProvider).isMuted('p-ada'),
        isTrue,
      );
      await _rightClick(tester, find.text('Ada Okafor'));
      expect(find.text('Unmute notifications'), findsOneWidget);
    });

    testWidgets('Delete conversation asks first, and Cancel deletes nothing', (
      tester,
    ) async {
      final actions = _Actions();
      await _pump(tester, actions: actions);
      await _rightClick(tester, find.text('Ada Okafor'));

      await tester.tap(find.text('Delete conversation'));
      await tester.pumpAndSettle();
      expect(find.text('Delete conversation?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(actions.deleted, isEmpty);
    });

    testWidgets('confirming Delete deletes the conversation', (tester) async {
      final actions = _Actions();
      await _pump(tester, actions: actions);
      await _rightClick(tester, find.text('Ada Okafor'));
      await tester.tap(find.text('Delete conversation'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Delete conversation'));
      await tester.pumpAndSettle();

      expect(actions.deleted, ['c-ada']);
    });

    testWidgets('says so when the delete fails', (tester) async {
      final actions = _Actions(deleteWorks: false);
      await _pump(tester, actions: actions);
      await _rightClick(tester, find.text('Ada Okafor'));
      await tester.tap(find.text('Delete conversation'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Delete conversation'));
      await tester.pump();

      expect(
        find.text("Couldn't delete the conversation. Try again."),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('a left click still opens the DM and no menu', (tester) async {
      final container = await _pump(tester);

      await tester.tap(find.text('Ada Okafor'));
      await tester.pumpAndSettle();

      expect(find.text('Pin conversation'), findsNothing);
      expect(container.read(selectedDmProvider)?.channelId, 'c-ada');
    });
  });
}
