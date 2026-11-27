import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

class _FakeThemeModeNotifier extends AppThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.system;

  @override
  Future<void> set(ThemeMode mode) async => state = mode;
}

/// The app root as app.dart wires it: the theme mode comes from the
/// provider, with the Appearance section on the page.
class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(appThemeModeProvider),
      home: const Scaffold(body: AppearanceSection()),
    );
  }
}

void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        appThemeModeProvider.overrideWith(_FakeThemeModeNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _App()),
    );
    return container;
  }

  testWidgets('offers Light, Dark and Auto with Auto selected', (tester) async {
    await pump(tester);

    expect(find.text('Appearance'), findsOneWidget);
    for (final label in ['Light', 'Dark', 'Auto']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(of: find.text('Auto'), matching: find.byType(Row)),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
  });

  testWidgets('picking Dark switches the app to the dark theme', (
    tester,
  ) async {
    final container = await pump(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(container.read(appThemeModeProvider), ThemeMode.dark);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      Theme.of(tester.element(find.text('Dark'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('picking Light switches the app to the light theme', (
    tester,
  ) async {
    final container = await pump(tester);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(container.read(appThemeModeProvider), ThemeMode.light);
    expect(
      Theme.of(tester.element(find.text('Light'))).brightness,
      Brightness.light,
    );
  });
}
