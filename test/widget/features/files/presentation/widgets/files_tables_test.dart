import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

const _shortName = 'Notes';
final _longName = 'Semester one lecture recordings and handouts ' * 6;

Future<void> _pumpFolders(WidgetTester tester, List<String> names) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    buildTestMaterialApp(
      Scaffold(
        body: SingleChildScrollView(
          child: FoldersTable(
            folders: [
              for (final name in names) FileFolder(id: name, name: name),
            ],
            ownerNameOf: (_) => 'Ada',
            onOpen: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The name in the row, plus one more when its tooltip is showing.
Finder get _longNameText => find.text(_longName);

/// Tooltips leave timers running, so remove them before the test ends.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  group('Files table names', () {
    testWidgets('a name that fits has no tooltip', (tester) async {
      await _pumpFolders(tester, [_shortName]);

      expect(find.text(_shortName), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);
      await _unmount(tester);
    });

    testWidgets('hovering a truncated name shows the full name', (
      tester,
    ) async {
      await _pumpFolders(tester, [_longName]);
      expect(_longNameText, findsOneWidget);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(_longNameText));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(_longNameText, findsNWidgets(2));
      await _unmount(tester);
    });

    testWidgets('keyboard focus on a truncated name shows the full name', (
      tester,
    ) async {
      await _pumpFolders(tester, [_longName]);

      // The first tab reaches the row, and the second reaches its name.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_longNameText, findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_longNameText, findsNWidgets(2));

      // Moving on hides it again.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_longNameText, findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('a name that fits adds no extra keyboard stop', (tester) async {
      await _pumpFolders(tester, [_shortName]);
      final before = find.byType(Focus).evaluate().length;

      await _pumpFolders(tester, [_longName]);

      expect(find.byType(Focus).evaluate().length, before + 1);
      await _unmount(tester);
    });

    testWidgets('screen readers get the full name', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpFolders(tester, [_longName]);

      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(_longName.trim()))),
        findsOneWidget,
      );
      semantics.dispose();
      await _unmount(tester);
    });

    testWidgets('a truncated name keeps the compact row height', (
      tester,
    ) async {
      await _pumpFolders(tester, [_shortName]);
      final compact = tester.getSize(find.byType(InkWell).first).height;

      await _pumpFolders(tester, [_longName]);

      expect(tester.getSize(find.byType(InkWell).first).height, compact);
      await _unmount(tester);
    });

    testWidgets('files get the same treatment as folders', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: SingleChildScrollView(
              child: FilesTable(
                files: [
                  WorkspaceFile.fromJson({
                    'id': 'f1',
                    'file_name': _longName,
                    'file_type': 'pdf',
                  }),
                ],
                ownerNameOf: (_) => 'Ada',
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip).first);
      expect(tooltip.message, contains('Semester one lecture recordings'));
      await _unmount(tester);
    });
  });
}
