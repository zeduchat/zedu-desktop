import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  const account = ProfileAccount(
    name: 'Ada Lovelace',
    username: 'ada',
    email: 'ada@example.com',
    timezone: 'Africa/Lagos',
    avatarUrl: 'https://cdn.zedu.test/ada.png',
  );

  late Future<String?> Function() originalPicker;
  setUp(() => originalPicker = pickProfilePhoto);
  tearDown(() => pickProfilePhoto = originalPicker);

  Future<List<ProfilePhotoEdit>> openAndSave(
    WidgetTester tester,
    Future<void> Function() edit, {
    ProfileAccount initial = account,
  }) async {
    final saved = <ProfilePhotoEdit>[];
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      buildTestMaterialApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showEditProfileDialog(context, initial, (_, photo) async {
                    saved.add(photo);
                    return null;
                  }),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await edit();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    return saved;
  }

  group('Edit profile photo (Ziki #12421)', () {
    testWidgets('shows the saved photo and saves a newly picked one', (
      tester,
    ) async {
      pickProfilePhoto = () async => 'C:/photos/new.png';

      final saved = await openAndSave(tester, () async {
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byKey(const ValueKey('edit_profile_photo')),
            matching: find.byType(Image),
          ),
        );
        expect(
          (image.image as NetworkImage).url,
          'https://cdn.zedu.test/ada.png',
        );
        await tester.tap(find.byKey(const ValueKey('edit_profile_upload')));
        await tester.pump();
      });

      expect(saved.single.filePath, 'C:/photos/new.png');
      expect(saved.single.remove, isFalse);
    });

    testWidgets('Remove photo saves a removal', (tester) async {
      final saved = await openAndSave(tester, () async {
        await tester.tap(find.byKey(const ValueKey('edit_profile_remove')));
        await tester.pump();
        expect(find.byKey(const ValueKey('edit_profile_remove')), findsNothing);
      });

      expect(saved.single.remove, isTrue);
    });

    testWidgets('rejects a file that is not a JPG or PNG', (tester) async {
      pickProfilePhoto = () async => 'C:/photos/anim.gif';
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        buildTestMaterialApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showEditProfileDialog(
                  context,
                  account,
                  (_, _) async => null,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('edit_profile_upload')));
      await tester.pump();

      expect(find.text('Choose a JPG or PNG image'), findsOneWidget);
    });

    testWidgets('an unchanged photo is saved as unchanged', (tester) async {
      final saved = await openAndSave(tester, () async {
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(AppTextField, 'Title'),
            matching: find.byType(TextFormField),
          ),
          'Engineer',
        );
      });

      expect(saved.single.isUnchanged, isTrue);
    });
  });
}
