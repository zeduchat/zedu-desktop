import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  const account = ProfileAccount(
    name: 'Ada Lovelace',
    username: 'ada',
    email: 'ada@example.com',
    timezone: 'Africa/Lagos',
  );

  late List<String> calls;
  late List<ProfileAvatarChange> avatarChanges;

  Future<void> openDialog(
    WidgetTester tester, {
    required PlatformFile? picked,
    ProfileAccount initial = account,
  }) async {
    calls = [];
    avatarChanges = [];
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
                initial,
                (_) async {
                  calls.add('profile');
                  return null;
                },
                onSaveAvatar: (change) async {
                  calls.add('avatar');
                  avatarChanges.add(change);
                  return null;
                },
                pickAvatar: () async => picked,
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

  Future<void> tapUpload(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('edit-profile-upload-photo')));
    await tester.pumpAndSettle();
  }

  testWidgets('rejects an image over 5 MB and does not upload it', (
    tester,
  ) async {
    await openDialog(
      tester,
      picked: PlatformFile(
        name: 'huge.png',
        size: ProfileAvatarChange.maxBytes + 1,
        bytes: Uint8List(ProfileAvatarChange.maxBytes + 1),
      ),
    );

    await tapUpload(tester);

    expect(find.text('Choose an image of 5 MB or less.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('edit-profile-photo-preview')),
      findsNothing,
    );

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(calls, ['profile']);
  });

  testWidgets('rejects a file that is not a PNG or JPEG', (tester) async {
    await openDialog(
      tester,
      picked: PlatformFile(name: 'me.gif', size: 10, bytes: Uint8List(10)),
    );

    await tapUpload(tester);

    expect(find.text('Choose a PNG or JPEG image.'), findsOneWidget);
  });

  testWidgets('previews a chosen photo and uploads it on save', (tester) async {
    final bytes = Uint8List.fromList(List.filled(32, 1));
    await openDialog(
      tester,
      picked: PlatformFile(name: 'me.png', size: bytes.length, bytes: bytes),
    );

    await tapUpload(tester);

    expect(
      find.byKey(const ValueKey('edit-profile-photo-preview')),
      findsOneWidget,
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(calls, ['profile', 'avatar']);
    expect(avatarChanges.single.isRemoval, isFalse);
    expect(avatarChanges.single.bytes, bytes);
    expect(avatarChanges.single.fileName, 'me.png');
    expect(find.text('Edit your profile'), findsNothing);
  });

  testWidgets('removes a saved photo on save', (tester) async {
    await openDialog(
      tester,
      picked: null,
      initial: account.copyWith(avatarUrl: 'https://cdn.zedu.test/ada.png'),
    );

    await tester.tap(find.byKey(const ValueKey('edit-profile-remove-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(avatarChanges.single.isRemoval, isTrue);
  });
}
