import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';
import '../../../../../unit/features/dms/fakes/buzz_call_fakes.dart';

class FakeActiveCallNotifier extends ActiveCallNotifier {
  FakeActiveCallNotifier(super.ref, {required bool isFullPage})
    : _fakeState = ActiveCallState(
        status: CallStatus.active,
        remoteUserName: 'Ruby',
        isFullPage: isFullPage,
      );

  final ActiveCallState _fakeState;

  @override
  ActiveCallState get state => _fakeState;
}

Widget buildBuzzMeetingViewUnderTest({required bool isFullPage}) {
  return ProviderScope(
    overrides: [
      activeCallProvider.overrideWith(
        (ref) => FakeActiveCallNotifier(ref, isFullPage: isFullPage),
      ),
    ],
    // The compact view is a Positioned, so it needs a Stack ancestor.
    child: MaterialApp(
      home: Scaffold(body: Stack(children: const [BuzzMeetingView()])),
    ),
  );
}

void main() {
  group('BuzzMeetingView participant label', () {
    testWidgets('compact view shows "2 participants"', (tester) async {
      await tester.pumpWidget(buildBuzzMeetingViewUnderTest(isFullPage: false));
      await tester.pump();

      expect(find.text('2 participants'), findsOneWidget);
      expect(find.text('2 participant'), findsNothing);
    });

    testWidgets('full-page view shows "2 participants"', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildBuzzMeetingViewUnderTest(isFullPage: true));
      await tester.pump();

      expect(find.text('2 participants'), findsOneWidget);
      expect(find.text('2 participant'), findsNothing);
    });
  });

  group('BuzzMeetingView share screen button', () {
    late FakeBuzzCallRepository repo;
    late FakeBuzzCallService media;
    late ProviderContainer container;

    ActiveCallNotifier calls() => container.read(activeCallProvider);

    /// An active full-page call with Bob, through the real notifier.
    Future<void> pumpActiveCall(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      repo = FakeBuzzCallRepository();
      media = FakeBuzzCallService();
      container = ProviderContainer(
        overrides: [
          buzzRepositoryProvider.overrideWithValue(repo),
          buzzCallServiceProvider.overrideWithValue(media),
          callSignalingProvider.overrideWithValue(FakeCallSignaling()),
          callRingtoneProvider.overrideWithValue(FakeRingtone()),
          authNotifierProvider.overrideWith(FakeSignedInAuthNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: Stack(children: const [BuzzMeetingView()])),
          ),
        ),
      );
      await calls().initiateCall(
        remoteUserId: 'bob',
        remoteUserName: 'Bob',
        channelId: 'dm-1',
      );
      await tester.pump();
      media
        ..emit(const BuzzRemoteIdentified(7, 'bob'))
        ..emit(const BuzzRemoteJoined(BuzzChannel.call, 7));
      await tester.pump();
      calls().setFullPage(true);
      await tester.pump();
      expect(calls().state.status, CallStatus.active);
    }

    testWidgets('lists sources, shares the picked one and stops sharing', (
      tester,
    ) async {
      await pumpActiveCall(tester);

      await tester.tap(find.byTooltip('Share screen'));
      await tester.pumpAndSettle();

      expect(find.text('Share your screen'), findsOneWidget);
      expect(find.text('Main display'), findsOneWidget);
      expect(find.text('Slides'), findsOneWidget);

      await tester.tap(find.text('Slides'));
      await tester.pumpAndSettle();

      expect(media.calls, contains('share:42'));
      expect(calls().state.isSharingScreen, isTrue);
      expect(find.byTooltip('Stop sharing'), findsOneWidget);
      expect(find.byIcon(Icons.stop_screen_share_outlined), findsOneWidget);

      await tester.tap(find.byTooltip('Stop sharing'));
      await tester.pumpAndSettle();

      expect(media.calls, contains('stop-share'));
      expect(calls().state.isSharingScreen, isFalse);
      expect(find.byTooltip('Share screen'), findsOneWidget);
    });

    testWidgets('dismissing the picker shares nothing', (tester) async {
      await pumpActiveCall(tester);

      await tester.tap(find.byTooltip('Share screen'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(media.calls.where((c) => c.startsWith('share:')), isEmpty);
      expect(find.byTooltip('Share screen'), findsOneWidget);
    });

    testWidgets('a failed start shows why and keeps the share button', (
      tester,
    ) async {
      await pumpActiveCall(tester);
      media.failScreenShare = true;

      await tester.tap(find.byTooltip('Share screen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main display'));
      await tester.pump();

      expect(find.text("Couldn't start sharing your screen."), findsOneWidget);
      expect(find.byTooltip('Share screen'), findsOneWidget);

      // Let the toast's auto-dismiss timer finish.
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets("shows someone else's shared screen", (tester) async {
      await pumpActiveCall(tester);
      expect(find.byKey(const ValueKey('buzz-remote-screen')), findsNothing);

      media
        ..emit(const BuzzRemoteIdentified(70, 'screen-bob'))
        ..emit(const BuzzRemoteVideoChanged(BuzzChannel.screen, 70, true));
      // The first pump delivers the media events, the second rebuilds.
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('buzz-remote-screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('remote-screen-70')), findsOneWidget);
      expect(find.text("Bob's screen"), findsOneWidget);

      media.emit(const BuzzRemoteVideoChanged(BuzzChannel.screen, 70, false));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('buzz-remote-screen')), findsNothing);
    });
  });
}
