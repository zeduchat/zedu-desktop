import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

const _org = OrganizationProfile(
  id: 'org-1',
  name: 'Acme',
  natureOfBusiness: 'Technology',
  country: 'Nigeria',
);

/// Pumps the section the way Settings lays it out: rail (50) and settings
/// navigation (320) on the left, then the content padding (28 left, 40 right).
Future<void> _pumpInSettingsLayout(
  WidgetTester tester, {
  required double windowWidth,
}) async {
  tester.view.physicalSize = Size(windowWidth, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    buildTestMaterialApp(
      Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 50 + 320),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 32, 40, 48),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: OrganizationSection(
                    organization: _org,
                    onSave: (_) {},
                    onDelete: () async {},
                    onLeave: () async {},
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Finder _button(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(OutlinedButton));

void main() {
  testWidgets(
    'action buttons do not overflow at the default 800 px window width',
    (tester) async {
      await _pumpInSettingsLayout(tester, windowWidth: 800);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(OrganizationSection)).width, 362);

      final sectionRight = tester
          .getTopRight(find.byType(OrganizationSection))
          .dx;
      for (final label in ['Sign out of workspace', 'Delete organization']) {
        expect(_button(label).hitTestable(), findsOneWidget);
        expect(
          tester.getTopRight(_button(label)).dx,
          lessThanOrEqualTo(sectionRight),
        );
      }
    },
  );

  testWidgets('action buttons stay on one row in a wide window', (
    tester,
  ) async {
    await _pumpInSettingsLayout(tester, windowWidth: 1600);

    expect(tester.takeException(), isNull);
    final leave = tester.getRect(_button('Sign out of workspace'));
    final delete = tester.getRect(_button('Delete organization'));
    expect(delete.top, leave.top);
    expect(delete.left, leave.right + 16);
  });

  testWidgets('renders organization avatar container with primaryBg token', (
    tester,
  ) async {
    const org = OrganizationProfile(
      id: 'org-1',
      name: 'Acme Corp',
      natureOfBusiness: 'Technology',
      country: 'US',
    );

    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: OrganizationSection(
            organization: org,
            onSave: (_) {},
            onDelete: () async {},
            onLeave: () async {},
          ),
        ),
      ),
    );

    expect(find.text('AC'), findsOneWidget);
    final containerFinder = find.ancestor(
      of: find.text('AC'),
      matching: find.byType(Container),
    );
    expect(containerFinder, findsWidgets);

    final containerWidget = tester.widget<Container>(containerFinder.first);
    final decoration = containerWidget.decoration as BoxDecoration?;
    expect(decoration?.color, equals(AppPalette.light.primaryBg));
  });

  testWidgets('Delete organization uses the error colour token', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: OrganizationSection(
            organization: const OrganizationProfile(
              id: 'org-1',
              name: 'Acme',
              natureOfBusiness: 'Technology',
              country: 'Nigeria',
            ),
            onSave: (_) {},
            onDelete: () async {},
            onLeave: () async {},
          ),
        ),
      ),
    );

    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Delete organization'),
        matching: find.byType(OutlinedButton),
      ),
    );
    final style = button.style!;
    final error = AppPalette.light.error;

    expect(style.foregroundColor!.resolve({}), error);
    expect(style.side!.resolve({})!.color, error);
  });
}
