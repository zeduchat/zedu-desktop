import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockDmRepository extends Mock implements DmRepository {}

Map<String, dynamic> _message(String id, [List<Map<String, dynamic>>? media]) =>
    {'id': id, 'content': 'msg $id', 'user_id': 'u1', 'media': ?media};

/// A full first page (so there is more), whose first message has report.pdf,
/// and a short second page with an older photo.png.
List<Map<String, dynamic>> _page(int page) {
  if (page == 1) {
    return [
      _message('m0', [
        {
          'file_name': 'report.pdf',
          'file_type': 'pdf',
          'file_link': 'https://files.test/report.pdf',
        },
      ]),
      for (var i = 1; i < DmRepository.pageSize; i++) _message('m$i'),
    ];
  }
  return [
    _message('old', [
      {
        'file_name': 'photo.png',
        'file_type': 'png',
        'file_link': 'https://files.test/photo.png',
      },
      {'file_name': 'nolink.txt', 'file_type': 'txt'},
    ]),
  ];
}

void main() {
  late MockDmRepository repository;
  late ProviderContainer container;
  late ChatHistoryNotifier history;
  late List<String> opened;

  setUp(() async {
    repository = MockDmRepository();
    when(
      () => repository.getMessages(any(), page: any(named: 'page')),
    ).thenAnswer((inv) async => _page(inv.namedArguments[#page] as int? ?? 1));
    container = ProviderContainer(
      overrides: [dmRepositoryProvider.overrideWithValue(repository)],
    );
    history = container.read(chatHistoryProvider('ch-1'));
    opened = [];
  });

  tearDown(() => container.dispose());

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: ConversationFilesDialog(
            title: 'Ada files',
            history: history,
            openLink: (link) async => opened.add(link),
          ),
        ),
      ),
    );
    // Let the first page and loadAll's older pages arrive.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  testWidgets('lists files from older pages too', (tester) async {
    await pumpDialog(tester);

    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('photo.png'), findsOneWidget);
    expect(find.text('Loading older files…'), findsNothing);
  });

  testWidgets('clicking a file opens its link', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.text('photo.png'));
    await tester.pump();

    expect(opened, ['https://files.test/photo.png']);
  });

  testWidgets('a file without a link is shown but cannot be opened', (
    tester,
  ) async {
    await pumpDialog(tester);

    await tester.tap(find.text('nolink.txt'));
    await tester.pump();

    expect(opened, isEmpty);
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('nolink.txt'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.enabled, isFalse);
  });
}
