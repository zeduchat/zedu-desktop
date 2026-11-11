import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

// Fake notifier that skips the repository lookup and profile load in build().
class FakeUserProfileNotifier extends UserProfileNotifier {
  FakeUserProfileNotifier({UserProfileState initial = const UserProfileState()})
    : _initial = initial;

  final UserProfileState _initial;

  @override
  UserProfileState build() => _initial;
}

Widget buildCreateOrganizationViewUnderTest({
  UserProfileState profileState = const UserProfileState(),
}) {
  return ProviderScope(
    overrides: [
      userProfileNotifierProvider.overrideWith(
        () => FakeUserProfileNotifier(initial: profileState),
      ),
    ],
    child: buildTestMaterialApp(const CreateOrganizationView()),
  );
}

Widget buildCreateOrganizationRouterUnderTest({
  UserProfileState profileState = const UserProfileState(),
  String initialLocation = AppRouter.createOrganization,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRouter.home,
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push(AppRouter.createOrganization),
            child: const Text('Open Create Org'),
          ),
        ),
      ),
      GoRoute(
        path: AppRouter.createOrganization,
        builder: (context, state) => const CreateOrganizationView(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      userProfileNotifierProvider.overrideWith(
        () => FakeUserProfileNotifier(initial: profileState),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('CreateOrganizationView', () {
    testWidgets('shows corrected hint text for name and type fields', (
      tester,
    ) async {
      await tester.pumpWidget(buildCreateOrganizationViewUnderTest());

      expect(find.text('Enter your organization name'), findsOneWidget);
      expect(find.text('What does your organization do?'), findsOneWidget);
      expect(find.text('Enter your organization Name'), findsNothing);
      expect(find.text('What does your organization do'), findsNothing);
    });

    testWidgets('country dropdown includes kCountries and Other option', (
      tester,
    ) async {
      await tester.pumpWidget(buildCreateOrganizationViewUnderTest());

      final dropdownFinder = find.byType(DropdownMenu<String>);
      expect(dropdownFinder, findsOneWidget);

      final dropdown = tester.widget<DropdownMenu<String>>(dropdownFinder);
      final entryValues = dropdown.dropdownMenuEntries
          .map((e) => e.value)
          .toList();

      for (final country in kCountries) {
        expect(
          entryValues.contains(country),
          isTrue,
          reason: '$country should be in dropdown entries',
        );
      }
      expect(entryValues.contains('Other'), isTrue);
      expect(entryValues.last, equals('Other'));
      expect(entryValues.length, equals(kCountries.length + 1));

      // Specifically verify countries that were previously omitted
      expect(entryValues.contains('Spain'), isTrue);
      expect(entryValues.contains('Ireland'), isTrue);
      expect(entryValues.contains('Afghanistan'), isTrue);
    });

    testWidgets('fills the form fields with the background token', (
      tester,
    ) async {
      await tester.pumpWidget(buildCreateOrganizationViewUnderTest());

      final background = AppPalette.light.background;
      final textFields = tester.widgetList<TextField>(
        find.descendant(
          of: find.byType(TextFormField),
          matching: find.byType(TextField),
        ),
      );
      final dropdown = tester.widget<DropdownMenu<String>>(
        find.byType(DropdownMenu<String>),
      );

      expect(textFields, hasLength(2));
      for (final field in textFields) {
        expect(field.decoration!.fillColor, background);
      }
      expect(dropdown.inputDecorationTheme!.fillColor, background);
    });

    testWidgets('renders back and cancel controls', (tester) async {
      await tester.pumpWidget(buildCreateOrganizationViewUnderTest());

      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('disables back and cancel controls while saving', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildCreateOrganizationViewUnderTest(
          profileState: const UserProfileState(isSaving: true),
        ),
      );

      final cancelButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancel'),
      );
      final backButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_back),
      );
      expect(cancelButton.onPressed, isNull);
      expect(backButton.onPressed, isNull);
    });

    testWidgets('back button pops when route was pushed', (tester) async {
      await tester.pumpWidget(
        buildCreateOrganizationRouterUnderTest(initialLocation: AppRouter.home),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Create Org'));
      await tester.pumpAndSettle();
      expect(find.text('Create Your Organization'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Create Your Organization'), findsNothing);
      expect(find.text('Open Create Org'), findsOneWidget);
    });

    testWidgets('cancel navigates to home when stack cannot pop', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildCreateOrganizationRouterUnderTest());
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Create Your Organization'), findsNothing);
      expect(find.text('Open Create Org'), findsOneWidget);
    });
  });
}
