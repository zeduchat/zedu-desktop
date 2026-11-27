import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

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

/// Records the mic and camera toggles and flips its state like the real
/// notifier does once the engine accepts the change.
class ToggleRecordingCallNotifier extends ActiveCallNotifier {
  ToggleRecordingCallNotifier(super.ref, {required bool isFullPage})
    : _fakeState = ActiveCallState(
        status: CallStatus.active,
        remoteUserName: 'Ruby',
        isFullPage: isFullPage,
      );

  ActiveCallState _fakeState;
  final toggles = <String>[];

  @override
  ActiveCallState get state => _fakeState;

  @override
  Future<void> toggleMicrophone() async {
    toggles.add('mic');
    _fakeState = _fakeState.copyWith(isMicMuted: !_fakeState.isMicMuted);
    notifyListeners();
  }

  @override
  Future<void> toggleCamera() async {
    toggles.add('camera');
    _fakeState = _fakeState.copyWith(isCameraOn: !_fakeState.isCameraOn);
    notifyListeners();
  }
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
    testWidgets('tells the user screen sharing is not available yet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildBuzzMeetingViewUnderTest(isFullPage: true));
      await tester.pump();

      const message = 'Screen sharing is not available yet.';
      expect(find.text(message), findsNothing);

      await tester.tap(find.byIcon(Icons.screen_share_outlined));
      await tester.pump();

      expect(find.text(message), findsOneWidget);

      // Let the toast's auto-dismiss timer finish.
      await tester.pump(const Duration(seconds: 10));
    });
  });

  group('BuzzMeetingView microphone and camera', () {
    late ToggleRecordingCallNotifier notifier;

    Widget buildWithToggles({required bool isFullPage}) {
      return ProviderScope(
        overrides: [
          activeCallProvider.overrideWith((ref) {
            return notifier = ToggleRecordingCallNotifier(
              ref,
              isFullPage: isFullPage,
            );
          }),
        ],
        child: MaterialApp(
          home: Scaffold(body: Stack(children: const [BuzzMeetingView()])),
        ),
      );
    }

    for (final isFullPage in [false, true]) {
      final view = isFullPage ? 'full-page' : 'compact';

      testWidgets('$view mute button toggles the call microphone', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildWithToggles(isFullPage: isFullPage));
        expect(find.byIcon(Icons.mic), findsOneWidget);

        await tester.tap(find.byIcon(Icons.mic));
        await tester.pump();

        expect(notifier.toggles, ['mic']);
        expect(notifier.state.isMicMuted, isTrue);
        expect(find.byIcon(Icons.mic_off), findsOneWidget);
        expect(find.byTooltip('Unmute'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.mic_off));
        await tester.pump();

        expect(notifier.toggles, ['mic', 'mic']);
        expect(find.byIcon(Icons.mic), findsOneWidget);
      });

      testWidgets('$view camera button toggles the call camera', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildWithToggles(isFullPage: isFullPage));
        // Joined without video, so the camera starts off.
        expect(find.byIcon(Icons.videocam_off), findsOneWidget);

        await tester.tap(find.byIcon(Icons.videocam_off));
        await tester.pump();

        expect(notifier.toggles, ['camera']);
        expect(notifier.state.isCameraOn, isTrue);
        expect(find.byIcon(Icons.videocam), findsOneWidget);
        expect(find.byTooltip('Turn camera off'), findsOneWidget);
      });
    }
  });
}
