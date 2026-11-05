import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

// Fake notifier that skips the repository lookup and profile load in build().
class FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();
}

Widget buildCreateOrganizationViewUnderTest() {
  return ProviderScope(
    overrides: [
      userProfileNotifierProvider.overrideWith(FakeUserProfileNotifier.new),
    ],
    child: buildTestMaterialApp(const CreateOrganizationView()),
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
  });
}
