import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

final _channel = Channel(
  id: 'c-1',
  name: 'general',
  description: 'General talk',
  organisationId: 'org-1',
  ownerId: 'u-1',
  topic: 'Anything goes',
);

Future<void> _open(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      child: buildTestMaterialApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => EditChannelModal(channel: _channel),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  group('EditChannelModal on narrow windows (Ziki #696)', () {
    testWidgets('fits a 360x640 window and scrolls to Save', (tester) async {
      await _open(tester, const Size(360, 640));

      expect(tester.takeException(), isNull);
      expect(find.byType(EditChannelModal), findsOneWidget);
      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Save changes').hitTestable(), findsOneWidget);
    });

    testWidgets('keeps its 400px width on a wide window', (tester) async {
      await _open(tester, const Size(1280, 900));

      final surface = find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first;
      expect(tester.getSize(surface).width, 400);
    });
  });
}
