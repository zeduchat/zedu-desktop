import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  late MockSecureStorageService storage;

  setUp(() {
    storage = MockSecureStorageService();
    when(() => storage.readData(any())).thenAnswer((_) async => null);
    when(() => storage.writeData(any(), any())).thenAnswer((_) async {});
    locator.registerSingleton<SecureStorageService>(storage);
  });

  tearDown(() async {
    await locator.reset();
  });

  Future<double Function()> pumpShortcut(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      ProviderScope(
        child: buildTestMaterialApp(
          AppZoomShortcut(
            child: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return () => MediaQuery.textScalerOf(captured).scale(1);
  }

  testWidgets('Ctrl+= zooms the text in and Ctrl+0 resets it', (tester) async {
    final scale = await pumpShortcut(tester);
    expect(scale(), 1.0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(scale(), closeTo(1.1, 0.001));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(scale(), 1.0);
  });

  testWidgets('Ctrl+- zooms the text out', (tester) async {
    final scale = await pumpShortcut(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(scale(), closeTo(0.9, 0.001));
  });

  Future<void> pressZoom(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    LogicalKeyboardKey modifier = LogicalKeyboardKey.controlLeft,
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(modifier);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    // A dedicated `+` key (German, Nordic, Swiss layouts) has no physical key
    // of its own in the simulator, so press it where German keyboards have it.
    final physicalKey = key == LogicalKeyboardKey.add
        ? PhysicalKeyboardKey.bracketRight
        : null;
    await tester.sendKeyDownEvent(key, physicalKey: physicalKey);
    await tester.sendKeyUpEvent(key, physicalKey: physicalKey);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  for (final modifier in [
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.metaLeft,
  ]) {
    final name = modifier == LogicalKeyboardKey.metaLeft ? 'Cmd' : 'Ctrl';

    testWidgets('$name+Shift+= zooms the text in (#7796)', (tester) async {
      final scale = await pumpShortcut(tester);

      await pressZoom(
        tester,
        LogicalKeyboardKey.equal,
        modifier: modifier,
        shift: true,
      );

      expect(scale(), closeTo(1.1, 0.001));
    });

    testWidgets('$name and a dedicated + key zoom the text in (#7796)', (
      tester,
    ) async {
      final scale = await pumpShortcut(tester);

      await pressZoom(tester, LogicalKeyboardKey.add, modifier: modifier);
      expect(scale(), closeTo(1.1, 0.001));

      await pressZoom(
        tester,
        LogicalKeyboardKey.add,
        modifier: modifier,
        shift: true,
      );
      expect(scale(), closeTo(1.25, 0.001));
    });
  }
}
