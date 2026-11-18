import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockDmRepository extends Mock implements DmRepository {}

Map<String, dynamic> _pin(String name, String text, String createdAt) => {
  'thread_id': 'thread-$name',
  'message': text,
  'full_name': name,
  'username': name.toLowerCase(),
  'created_at': createdAt,
  'type': 'thread',
};

void main() {
  late MockDmRepository repository;

  setUp(() => repository = MockDmRepository());

  /// The pin button in a chat header, with the repository the dialog reads.
  Future<void> pumpButton(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dmRepositoryProvider.overrideWithValue(repository)],
        child: buildTestMaterialApp(
          const Scaffold(
            body: Center(
              child: PinnedMessagesButton(
                channelId: 'ch-1',
                title: '# general pinned messages',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openPins(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Pinned messages'));
    await tester.pumpAndSettle();
  }

  testWidgets('the header pin button lists the server pins, newest first', (
    tester,
  ) async {
    when(() => repository.getPinnedMessages('ch-1')).thenAnswer(
      (_) async => [
        _pin('Ada', 'Older **plan**', '2026-11-01T10:00:00Z'),
        _pin('Bola', 'Newest note', '2026-11-12T10:00:00Z'),
      ],
    );
    await pumpButton(tester);

    await openPins(tester);

    verify(() => repository.getPinnedMessages('ch-1')).called(1);
    expect(find.text('# general pinned messages'), findsOneWidget);
    // Markdown marks are stripped, as in the message list.
    expect(find.text('Older plan'), findsOneWidget);
    expect(find.text('12 Nov 2026'), findsOneWidget);
    final newest = tester.getTopLeft(find.text('Bola')).dy;
    final older = tester.getTopLeft(find.text('Ada')).dy;
    expect(newest, lessThan(older));
  });

  testWidgets('says so when nothing is pinned', (tester) async {
    when(
      () => repository.getPinnedMessages('ch-1'),
    ).thenAnswer((_) async => []);
    await pumpButton(tester);

    await openPins(tester);

    expect(find.text('No pinned messages yet.'), findsOneWidget);
  });

  testWidgets('a failed load offers Retry, which loads again', (tester) async {
    var calls = 0;
    when(() => repository.getPinnedMessages('ch-1')).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw const ApiFailure(message: 'Request failed.');
      }
      return [_pin('Ada', 'Back again', '2026-11-02T10:00:00Z')];
    });
    await pumpButton(tester);

    await openPins(tester);
    expect(find.text("Couldn't load the pinned messages."), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Back again'), findsOneWidget);
  });
}
