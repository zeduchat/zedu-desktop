import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class FakeActiveCallNotifier extends ActiveCallNotifier {
  FakeActiveCallNotifier(
    super.ref, {
    required bool isFullPage,
    List<CallParticipant> participants = const [
      CallParticipant(userId: 'ruby', name: 'Ruby'),
    ],
  }) : _fakeState = ActiveCallState(
         status: CallStatus.active,
         remoteUserName: 'Ruby',
         isFullPage: isFullPage,
         participants: participants,
       );

  final ActiveCallState _fakeState;

  @override
  ActiveCallState get state => _fakeState;
}

Widget buildBuzzMeetingViewUnderTest({
  required bool isFullPage,
  List<CallParticipant>? participants,
}) {
  return ProviderScope(
    overrides: [
      activeCallProvider.overrideWith(
        (ref) => participants == null
            ? FakeActiveCallNotifier(ref, isFullPage: isFullPage)
            : FakeActiveCallNotifier(
                ref,
                isFullPage: isFullPage,
                participants: participants,
              ),
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

  group('BuzzMeetingView participant count', () {
    const three = [
      CallParticipant(userId: 'ruby', name: 'Ruby'),
      CallParticipant(userId: 'sam', name: 'Sam'),
    ];

    for (final isFullPage in [false, true]) {
      final view = isFullPage ? 'full-page' : 'compact';

      testWidgets('$view view says "1 participant" when alone', (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          buildBuzzMeetingViewUnderTest(
            isFullPage: isFullPage,
            participants: const [],
          ),
        );
        await tester.pump();

        expect(find.text('1 participant'), findsOneWidget);
        expect(find.text('2 participants'), findsNothing);
      });

      testWidgets('$view view counts everyone in a group call', (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          buildBuzzMeetingViewUnderTest(
            isFullPage: isFullPage,
            participants: three,
          ),
        );
        await tester.pump();

        expect(find.text('3 participants'), findsOneWidget);
        expect(find.text('2 participants'), findsNothing);
      });
    }
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
}
