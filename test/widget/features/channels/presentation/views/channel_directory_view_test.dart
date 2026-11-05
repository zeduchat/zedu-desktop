import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

final _general = Channel(
  id: 'c-1',
  name: 'general',
  description: '',
  organisationId: 'org-1',
  isPrivate: false,
  ownerId: 'u-1',
  archived: false,
  unreadCount: 0,
  membersCount: 1,
);

/// Answers each load with the next result, repeating the last one.
class _FakeChannelNotifier extends ChannelNotifier {
  _FakeChannelNotifier(this.results);

  final List<List<Channel>?> results;
  var _loads = 0;

  @override
  Future<List<Channel>> build() async {
    final index = _loads < results.length ? _loads : results.length - 1;
    _loads++;
    final result = results[index];
    if (result == null) throw const ApiFailure(message: 'offline');
    return result;
  }
}

Future<void> _pump(WidgetTester tester, List<List<Channel>?> results) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        channelProvider.overrideWith(() => _FakeChannelNotifier(results)),
      ],
      child: buildTestMaterialApp(const Scaffold(body: ChannelDirectoryView())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows an error and Retry when the channels fail to load', (
    tester,
  ) async {
    await _pump(tester, [null]);

    expect(find.text("Couldn't load channels"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No channels found.'), findsNothing);
  });

  testWidgets('shows the error while a search is typed', (tester) async {
    await _pump(tester, [null]);

    await tester.enterText(find.byType(TextField), 'gen');
    await tester.pump();

    expect(find.text("Couldn't load channels"), findsOneWidget);
    expect(find.text('No channels found.'), findsNothing);
  });

  testWidgets('Retry reloads the channels', (tester) async {
    await _pump(tester, [
      null,
      [_general],
    ]);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('general'), findsOneWidget);
    expect(find.text("Couldn't load channels"), findsNothing);
  });

  testWidgets('Retry shows the error again when the reload fails', (
    tester,
  ) async {
    await _pump(tester, [null, null]);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load channels"), findsOneWidget);
  });

  testWidgets('says No channels found for a real empty list', (tester) async {
    await _pump(tester, [const []]);

    expect(find.text('No channels found.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('says No channels found for an empty search', (tester) async {
    await _pump(tester, [
      [_general],
    ]);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();

    expect(find.text('No channels found.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
