import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

Future<void> drainToastTimer(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

class ErrorUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();

  @override
  Future<List<TeamMember>> fetchOrganisationMembers() async => [];

  @override
  Future<void> inviteMember({
    required String email,
    required String role,
    String? userId,
  }) async {
    state = const UserProfileState(error: 'Failed to invite member');
  }
}

// The members the fake organisation has; anyone else is not in it.
List<TeamMember> orgMembers = [];

// Avoids the locator and API: serves [orgMembers], invites are recorded.
class FakeUserProfileNotifier extends UserProfileNotifier {
  final List<String> invited = [];
  Future<void> Function(String email)? onInvite;

  @override
  UserProfileState build() => const UserProfileState();

  @override
  Future<List<TeamMember>> fetchOrganisationMembers() async => orgMembers;

  @override
  Future<void> inviteMember({
    required String email,
    required String role,
    String? userId,
  }) async {
    invited.add(email);
    final hook = onInvite;
    if (hook != null) await hook(email);
    if (state.error == null) state = const UserProfileState();
  }
}

class FakeAddEveryoneToChannel extends AddEveryoneToChannel {
  FakeAddEveryoneToChannel(super.ref, this._result);

  final Future<AddEveryoneResult> Function() _result;
  int calls = 0;

  @override
  Future<AddEveryoneResult> call() {
    calls++;
    return _result();
  }
}

late FakeAddEveryoneToChannel fakeAddEveryone;
late FakeUserProfileNotifier fakeUserProfile;

// Lets a test open the window while a given channel is open in the sidebar.
class FakeActiveChatNotifier extends ActiveChatNotifier {
  FakeActiveChatNotifier(this._initial);

  final ActiveChatState _initial;

  @override
  ActiveChatState build() => _initial;
}

Widget buildModalUnderTest(
  Future<AddEveryoneResult> Function() result, {
  ActiveChatState chat = ActiveChatState.generalChannel,
}) {
  return ProviderScope(
    overrides: [
      userProfileNotifierProvider.overrideWith(
        () => fakeUserProfile = FakeUserProfileNotifier(),
      ),
      activeChatProvider.overrideWith(() => FakeActiveChatNotifier(chat)),
      addEveryoneToChannelProvider.overrideWith(
        (ref) => fakeAddEveryone = FakeAddEveryoneToChannel(ref, result),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              // The test font draws every glyph as a full square, so the
              // 20px title is wider than in the app. Shrink text to fit.
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(0.7)),
                child: const InviteTeammatesModal(),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> openModal(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  expect(find.byType(InviteTeammatesModal), findsOneWidget);
}

Future<void> addRecipient(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextField), email);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  setUp(() => orgMembers = []);

  for (final entry in {
    1: 'Successfully invited 1 teammate.',
    2: 'Successfully invited 2 teammates.',
  }.entries) {
    testWidgets('invitation success copy for ${entry.key} recipients', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildModalUnderTest(
          () async => const AddEveryoneNobodyToAdd('general'),
        ),
      );
      await openModal(tester);

      for (var i = 0; i < entry.key; i++) {
        await tester.enterText(find.byType(TextField), 'person$i@example.com');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
      }
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(InviteTeammatesModal), findsNothing);
    });
  }

  testWidgets('shows the invite hint without a leading pipe', (tester) async {
    await tester.pumpWidget(
      buildModalUnderTest(() async => const AddEveryoneNobodyToAdd('general')),
    );
    await openModal(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.hintText, 'Enter name or email');
  });

  group('InviteTeammatesModal suggestions', () {
    TeamMember member(String id, String email, String? name) => TeamMember(
      id: id,
      email: email,
      role: 'User',
      dateJoined: '',
      status: TeamMemberStatus.active,
      name: name,
    );

    testWidgets('suggest organisation members by their name', (tester) async {
      orgMembers = [
        member('u1', 'alice@zedu.chat', 'Alice Ade'),
        member('u2', 'carol@zedu.chat', null),
      ];
      await tester.pumpWidget(
        buildModalUnderTest(
          () async => const AddEveryoneNobodyToAdd('general'),
        ),
      );
      await openModal(tester);

      await tester.enterText(find.byType(TextField), 'zedu');
      await tester.pump();

      expect(find.text('Alice Ade'), findsOneWidget);
      expect(find.text('alice@zedu.chat'), findsOneWidget);
      // No profile name: falls back to the email name, never "Unknown".
      expect(find.text('carol'), findsOneWidget);
      expect(find.text('Unknown'), findsNothing);
    });

    testWidgets('never suggest someone outside the organisation', (
      tester,
    ) async {
      orgMembers = [member('u1', 'alice@zedu.chat', 'Alice Ade')];
      await tester.pumpWidget(
        buildModalUnderTest(
          () async => const AddEveryoneNobodyToAdd('general'),
        ),
      );
      await openModal(tester);

      await tester.enterText(find.byType(TextField), 'desk4');
      await tester.pump();

      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('InviteTeammatesModal "Add everyone"', () {
    testWidgets('adds everyone, shows how many and closes the window', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildModalUnderTest(() async => const AddEveryoneAdded(3, 'general')),
      );
      await openModal(tester);

      await tester.tap(find.text('Add everyone'));
      await tester.pumpAndSettle();

      expect(fakeAddEveryone.calls, 1);
      expect(find.text('Added 3 people to #general.'), findsOneWidget);
      expect(find.byType(InviteTeammatesModal), findsNothing);
      await drainToastTimer(tester);
    });

    testWidgets('says "person" when one person is added', (tester) async {
      await tester.pumpWidget(
        buildModalUnderTest(() async => const AddEveryoneAdded(1, 'general')),
      );
      await openModal(tester);

      await tester.tap(find.text('Add everyone'));
      await tester.pumpAndSettle();

      expect(find.text('Added 1 person to #general.'), findsOneWidget);
      await drainToastTimer(tester);
    });

    testWidgets('keeps the window open when everyone is already in', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildModalUnderTest(
          () async => const AddEveryoneNobodyToAdd('general'),
        ),
      );
      await openModal(tester);

      await tester.tap(find.text('Add everyone'));
      await tester.pumpAndSettle();

      expect(
        find.text('Everyone in your organisation is already in #general.'),
        findsOneWidget,
      );
      expect(find.byType(InviteTeammatesModal), findsOneWidget);
      await drainToastTimer(tester);
    });

    testWidgets('shows the error and keeps the window open on failure', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildModalUnderTest(
          () async => const AddEveryoneFailed('failed to add users to channel'),
        ),
      );
      await openModal(tester);

      await tester.tap(find.text('Add everyone'));
      await tester.pumpAndSettle();

      expect(find.text('failed to add users to channel'), findsOneWidget);
      expect(find.byType(InviteTeammatesModal), findsOneWidget);
      expect(find.text('Add everyone'), findsOneWidget);
      await drainToastTimer(tester);
    });

    testWidgets('is disabled while adding, so a second click does nothing', (
      tester,
    ) async {
      final pending = Completer<AddEveryoneResult>();
      await tester.pumpWidget(buildModalUnderTest(() => pending.future));
      await openModal(tester);

      await tester.tap(find.text('Add everyone'));
      await tester.pump();

      expect(find.text('Adding…'), findsOneWidget);
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Adding…'),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.text('Adding…'));
      await tester.pump();
      expect(fakeAddEveryone.calls, 1);

      pending.complete(const AddEveryoneNobodyToAdd('general'));
      await tester.pumpAndSettle();
      expect(find.text('Add everyone'), findsOneWidget);
      await drainToastTimer(tester);
    });

    testWidgets('names the channel that is open, in the title and messages', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildModalUnderTest(
          () async => const AddEveryoneAdded(2, 'design'),
          chat: const ActiveChatState(
            type: ActiveChatType.channel,
            id: 'design',
          ),
        ),
      );
      await openModal(tester);

      expect(find.text('Add people to #design'), findsOneWidget);
      expect(find.text('Add people to #general'), findsNothing);

      await tester.tap(find.text('Add everyone'));
      await tester.pumpAndSettle();

      expect(find.text('Added 2 people to #design.'), findsOneWidget);
      await drainToastTimer(tester);
    });

    testWidgets('keeps a very long channel name inside the title', (
      tester,
    ) async {
      final longName = 'a-very-long-channel-name-' * 8;
      await tester.pumpWidget(
        buildModalUnderTest(
          () async => AddEveryoneNobodyToAdd(longName),
          chat: ActiveChatState(type: ActiveChatType.channel, id: longName),
        ),
      );
      await openModal(tester);

      // A RenderFlex overflow would be reported as an exception here.
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Add people to #a-very-long'), findsOneWidget);
    });

    testWidgets('leaves Copy Invite Link and Add in place', (tester) async {
      await tester.pumpWidget(
        buildModalUnderTest(
          () async => const AddEveryoneNobodyToAdd('general'),
        ),
      );
      await openModal(tester);

      expect(find.byTooltip('Copy Invite Link'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Add'), findsOneWidget);
    });
  });

  // Regression for https://ziki.dev/zedu/web/issues/462
  group('InviteTeammatesModal submission stability', () {
    testWidgets('control: three unchanged recipients are all invited', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildModalUnderTest(
          () async => const AddEveryoneNobodyToAdd('general'),
        ),
      );
      await openModal(tester);

      await addRecipient(tester, 'one@test.com');
      await addRecipient(tester, 'two@test.com');
      await addRecipient(tester, 'three@test.com');
      expect(find.byType(Chip), findsNWidgets(3));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(fakeUserProfile.invited, [
        'one@test.com',
        'two@test.com',
        'three@test.com',
      ]);
      expect(tester.takeException(), isNull);
      expect(find.byType(InviteTeammatesModal), findsNothing);
    });

    testWidgets(
      'disables chip removal while submitting and still completes a slow batch',
      (tester) async {
        final firstRequest = Completer<void>();
        await tester.pumpWidget(
          buildModalUnderTest(
            () async => const AddEveryoneNobodyToAdd('general'),
          ),
        );
        await openModal(tester);

        await addRecipient(tester, 'one@test.com');
        await addRecipient(tester, 'two@test.com');
        await addRecipient(tester, 'three@test.com');

        fakeUserProfile.onInvite = (email) async {
          if (email == 'one@test.com') await firstRequest.future;
        };

        await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
        // First pump rebuilds (starting the Chip delete-icon exit animation
        // of _kDrawerDuration); the second advances past it so the removed
        // delete icons leave the tree.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Recipient editing is blocked during the in-flight submission.
        expect(
          find.descendant(
            of: find.byType(Chip),
            matching: find.byIcon(Icons.close),
          ),
          findsNothing,
        );

        firstRequest.complete();
        await tester.pumpAndSettle();

        // The full snapshot is attempted: no skipped invites, no stuck
        // spinner, and the dialog closes after the successful batch.
        expect(fakeUserProfile.invited, [
          'one@test.com',
          'two@test.com',
          'three@test.com',
        ]);
        expect(tester.takeException(), isNull);
        expect(find.byType(InviteTeammatesModal), findsNothing);
      },
    );

    testWidgets('returns Add to a usable state when an invite throws', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildModalUnderTest(
          () async => const AddEveryoneNobodyToAdd('general'),
        ),
      );
      await openModal(tester);

      await addRecipient(tester, 'one@test.com');
      await addRecipient(tester, 'two@test.com');

      fakeUserProfile.onInvite = (_) async {
        throw Exception('network error');
      };

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.byType(InviteTeammatesModal), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('returns Add to a usable state when the batch fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildModalUnderTest(
          () async => const AddEveryoneNobodyToAdd('general'),
        ),
      );
      await openModal(tester);

      await addRecipient(tester, 'one@test.com');
      await addRecipient(tester, 'two@test.com');

      fakeUserProfile.onInvite = (_) async {
        fakeUserProfile.state = const UserProfileState(error: 'Invite failed.');
      };

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Invite failed.'), findsOneWidget);
      expect(find.byType(InviteTeammatesModal), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add'),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  group('InviteTeammatesModal email validation', () {
    const errorText = 'Please enter a valid email address.';

    Future<FakeUserProfileNotifier> pumpModal(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // The fixed 480px dialog's button row only overflows with the wide
      // Ahem test font; ignore that layout warning, keep every other error.
      final onError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        onError?.call(details);
      };
      addTearDown(() => FlutterError.onError = onError);
      final notifier = FakeUserProfileNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileNotifierProvider.overrideWith(() => notifier),
            activeChatProvider.overrideWith(
              () => FakeActiveChatNotifier(ActiveChatState.generalChannel),
            ),
          ],
          child: buildTestMaterialApp(
            const Scaffold(body: InviteTeammatesModal()),
          ),
        ),
      );
      await tester.pump();
      return notifier;
    }

    Future<void> submitText(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }

    for (final invalid in ['@@@', 'abc@', 'name@domain']) {
      testWidgets('rejects "$invalid" with an error', (tester) async {
        await pumpModal(tester);

        await submitText(tester, invalid);

        expect(find.byType(Chip), findsNothing);
        expect(find.text(errorText), findsOneWidget);
      });
    }

    testWidgets('clears the error when the user types again', (tester) async {
      await pumpModal(tester);
      await submitText(tester, 'abc@');
      expect(find.text(errorText), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'abc@zedu.chat');
      await tester.pump();

      expect(find.text(errorText), findsNothing);
    });

    testWidgets('adds a valid email as an invite', (tester) async {
      await pumpModal(tester);

      await submitText(tester, ' ada@example.com ');

      expect(find.widgetWithText(Chip, 'ada@example.com'), findsOneWidget);
      expect(find.text(errorText), findsNothing);
    });

    testWidgets('adds the same email in different case only once', (
      tester,
    ) async {
      await pumpModal(tester);

      await submitText(tester, 'Ada@example.com');
      await submitText(tester, 'ada@example.com');

      expect(find.byType(Chip), findsOneWidget);
    });

    testWidgets('Add with invalid text left in the box sends nothing', (
      tester,
    ) async {
      final notifier = await pumpModal(tester);
      await submitText(tester, 'ada@example.com');
      await tester.enterText(find.byType(TextField), 'abc@');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pump();

      expect(notifier.invited, isEmpty);
      expect(find.text(errorText), findsOneWidget);
    });
  });

  group('InviteTeammatesModal error toasts', () {
    testWidgets('shows error toast when submit fails', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notifier = ErrorUserProfileNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileNotifierProvider.overrideWith(() => notifier),
            activeChatProvider.overrideWith(
              () => FakeActiveChatNotifier(ActiveChatState.generalChannel),
            ),
          ],
          child: buildTestMaterialApp(
            const Scaffold(body: InviteTeammatesModal()),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'team@example.com');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Failed to invite member'), findsOneWidget);
      await drainToastTimer(tester);
    });
  });
}
