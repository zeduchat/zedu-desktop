import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  const noPhoto = ProfileAccount(
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    timezone: 'Africa/Lagos',
  );

  Future<void> openDialog(
    WidgetTester tester, {
    ProfileAccount account = noPhoto,
    EditProfilePhotoUpload? onUpload,
    EditProfilePhotoRemove? onRemove,
    EditProfilePhotoPicker? pick,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      buildTestMaterialApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showEditProfileDialog(
                context,
                account,
                (_) async => null,
                onUploadPhoto: onUpload,
                onRemovePhoto: onRemove,
                pickPhoto: pick ?? () async => null,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  TextButton buttonWith(WidgetTester tester, String label) =>
      tester.widget<TextButton>(
        find.ancestor(of: find.text(label), matching: find.byType(TextButton)),
      );

  testWidgets('Upload photo sends the picked image', (tester) async {
    String? uploaded;
    await openDialog(
      tester,
      onUpload: (path) async {
        uploaded = path;
        return null;
      },
      onRemove: () async => null,
      pick: () async => 'C:/pics/ada.png',
    );

    await tester.tap(find.text('Upload photo'));
    await tester.pump();
    await tester.pump();

    expect(uploaded, 'C:/pics/ada.png');
    expect(buttonWith(tester, 'Remove photo').onPressed, isNotNull);
  });

  testWidgets('a file that is not JPG or PNG is refused before uploading', (
    tester,
  ) async {
    var uploads = 0;
    await openDialog(
      tester,
      onUpload: (_) async {
        uploads++;
        return null;
      },
      pick: () async => 'C:/docs/cv.pdf',
    );

    await tester.tap(find.text('Upload photo'));
    await tester.pump();

    expect(uploads, 0);
    expect(find.text('Choose a JPG or PNG image.'), findsOneWidget);
  });

  testWidgets('a failed upload shows the error', (tester) async {
    await openDialog(
      tester,
      onUpload: (_) async => 'Upload failed. Try again.',
      pick: () async => 'C:/pics/ada.jpg',
    );

    await tester.tap(find.text('Upload photo'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Upload failed. Try again.'), findsOneWidget);
  });

  testWidgets('cancelling the picker uploads nothing', (tester) async {
    var uploads = 0;
    await openDialog(
      tester,
      onUpload: (_) async {
        uploads++;
        return null;
      },
    );

    await tester.tap(find.text('Upload photo'));
    await tester.pump();

    expect(uploads, 0);
  });

  testWidgets('Remove photo removes a saved photo', (tester) async {
    var removals = 0;
    await openDialog(
      tester,
      account: noPhoto.copyWith(avatarUrl: 'https://cdn.zedu.chat/ada.png'),
      onUpload: (_) async => null,
      onRemove: () async {
        removals++;
        return null;
      },
    );

    await tester.tap(find.text('Remove photo'));
    await tester.pump();
    await tester.pump();

    expect(removals, 1);
    // Nothing left to remove.
    expect(buttonWith(tester, 'Remove photo').onPressed, isNull);
  });

  testWidgets('Remove photo is disabled when there is no photo', (
    tester,
  ) async {
    await openDialog(
      tester,
      onUpload: (_) async => null,
      onRemove: () async => null,
    );

    expect(buttonWith(tester, 'Remove photo').onPressed, isNull);
  });

  testWidgets('without photo actions the buttons are not shown', (
    tester,
  ) async {
    await openDialog(tester);

    expect(find.text('Upload photo'), findsNothing);
    expect(find.text('Remove photo'), findsNothing);
  });
}
