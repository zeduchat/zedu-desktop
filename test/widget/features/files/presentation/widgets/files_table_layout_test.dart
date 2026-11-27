import 'dart:io';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

/// Width of the Files table in the default 800 px window: 800 minus the 50 px
/// rail, the 320 px sidebar and the page's 24 px padding on each side.
const _defaultTableWidth = 800.0 - 50 - 320 - 24 * 2;

// The default test font has different metrics, so load the app's real fonts.
Future<void> _loadAppFonts() async {
  final loader = FontLoader('Lato');
  for (final weight in ['Regular', 'Bold']) {
    final bytes = File('assets/fonts/Lato/Lato-$weight.ttf');
    loader.addFont(Future.value(ByteData.sublistView(bytes.readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _pumpTable(WidgetTester tester, double width) async {
  tester.view.physicalSize = const Size(1600, 628);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    // The Shared in cell loads each file's info; this file is shared nowhere.
    ProviderScope(
      overrides: [
        fileInfoProvider.overrideWith(
          (ref, fileId) async => const WorkspaceFileInfo(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: FilesTable(
                files: [
                  WorkspaceFile(
                    id: 'f-1',
                    name: 'screenshot.png',
                    fileType: 'png',
                    size: 120 * 1024,
                    updatedAt: DateTime(2026, 11, 30),
                  ),
                ],
                ownerNameOf: (_) => 'Ada Lovelace',
                onOpen: (_) {},
                onDelete: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Whether [text] is laid out in full on one line, with no ellipsis or wrap.
bool _fitsOnOneLine(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  return paragraph.getMaxIntrinsicWidth(double.infinity) <=
      paragraph.constraints.maxWidth;
}

void main() {
  setUpAll(_loadAppFonts);

  testWidgets(
    'shows the full size and a one-line Date Modified at the default window',
    (tester) async {
      await _pumpTable(tester, _defaultTableWidth);

      expect(tester.takeException(), isNull);
      expect(find.text('120 KB'), findsOneWidget);
      expect(_fitsOnOneLine(tester, '120 KB'), isTrue);
      expect(_fitsOnOneLine(tester, 'Date Modified'), isTrue);
      expect(_fitsOnOneLine(tester, 'Nov 30, 2026'), isTrue);
    },
  );

  testWidgets('keeps every column in a wide window', (tester) async {
    await _pumpTable(tester, 1280.0 - 50 - 320 - 24 * 2);

    expect(tester.takeException(), isNull);
    for (final label in [
      'Name',
      'Shared in',
      'Owner',
      'Date Modified',
      'Size',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(_fitsOnOneLine(tester, '120 KB'), isTrue);
  });

  testWidgets('lays out without overflow in a very narrow table', (
    tester,
  ) async {
    await _pumpTable(tester, 240);

    expect(tester.takeException(), isNull);
    expect(find.text('120 KB'), findsOneWidget);
  });
}
