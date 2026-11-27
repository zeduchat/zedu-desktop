import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

/// Renders Settings > Account at a fixed size so the section
/// can be captured as a golden image for the pull request evidence.
///
/// The file only depends on [AccountSection], so it also runs on the
/// destination branch to produce the "before" picture.
Future<void> _loadAppFonts() async {
  for (final family in ['Lato', 'Roboto']) {
    final loader = FontLoader(family);
    for (final weight in ['Regular', 'Bold']) {
      final bytes = File('assets/fonts/$family/$family-$weight.ttf');
      if (bytes.existsSync()) {
        loader.addFont(
          Future.value(ByteData.sublistView(bytes.readAsBytesSync())),
        );
      }
    }
    await loader.load();
  }

  var flutterRoot = File(Platform.resolvedExecutable).parent;
  File? iconFont;
  while (flutterRoot.path != flutterRoot.parent.path) {
    for (final name in [
      'MaterialIcons-Regular.otf',
      'materialicons-regular.otf',
    ]) {
      final candidate = File(
        [
          flutterRoot.path,
          'bin',
          'cache',
          'artifacts',
          'material_fonts',
          name,
        ].join(Platform.pathSeparator),
      );
      if (candidate.existsSync()) {
        iconFont = candidate;
        break;
      }
    }
    if (iconFont != null) break;
    flutterRoot = flutterRoot.parent;
  }
  if (iconFont == null || !iconFont.existsSync()) {
    throw StateError('Flutter Material Icons font was not found.');
  }
  await (FontLoader('MaterialIcons')..addFont(
        Future.value(ByteData.sublistView(iconFont.readAsBytesSync())),
      ))
      .load();
}

Widget _buildAccountSection() {
  // The test runner's default font draws every glyph as a box, and the app's
  // outlined-button label style carries no font family, so the capture pins
  // the body font on it. Nothing else about the section is changed.
  final outlined = AppTheme.light.outlinedButtonTheme.style!;
  final theme = AppTheme.light.copyWith(
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: outlined.copyWith(
        textStyle: WidgetStatePropertyAll(
          outlined.textStyle!
              .resolve(const <WidgetState>{})!
              .copyWith(fontFamily: FontFamily.lato),
        ),
      ),
    ),
  );

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: AccountSection(
          account: const ProfileAccount(
            name: 'Adaeze Okonkwo',
            email: 'adaeze@zedu.chat',
            timezone: 'Africa/Lagos',
            username: 'adaeze',
          ),
          isSaving: false,
          onSave: (_, _) async => null,
          onDelete: () async {},
        ),
      ),
    ),
  );
}

// Golden files are compared on CI's Linux runner while the committed image
// was captured on Windows, where fonts rasterise slightly differently. The
// repo's invite CTA test allows a small pixel difference for this reason;
// this does the same, at the same 5% tolerance.
class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile, {this.tolerance = 0.05});

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    final passed = result.passed || result.diffPercent <= tolerance;
    if (passed) {
      result.dispose();
      return true;
    }

    final String error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

void _useTolerantGoldenComparator(String testFileName) {
  final currentComparator = goldenFileComparator;
  if (currentComparator is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenComparator(
      currentComparator.basedir.resolve(testFileName),
      tolerance: 0.05,
    );
  }
}

void main() {
  setUpAll(() async {
    await _loadAppFonts();
    _useTolerantGoldenComparator('account_section_screenshot_test.dart');
  });

  testWidgets('captures the account settings section', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildAccountSection());
    await tester.pumpAndSettle();

    expect(find.text('Personal details'), findsOneWidget);
    expect(
      find.text('Adaeze Okonkwo'),
      findsNWidgets(2),
    ); // header + Display name
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/account_section.png'),
    );
  });
}
