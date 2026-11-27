import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../../helpers/helpers.dart';

Future<void> _pump(WidgetTester tester, ProfileAccount account) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    buildTestMaterialApp(
      Scaffold(
        body: SingleChildScrollView(
          child: AccountSection(
            account: account,
            isSaving: false,
            onSave: (_, _) async => null,
            onDelete: () async {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  const account = ProfileAccount(
    name: 'Ada Lovelace',
    email: 'ada@zedu.test',
    timezone: 'Africa/Lagos',
  );

  testWidgets('shows the initials when there is no avatar', (tester) async {
    await _pump(tester, account);

    expect(find.text('AL'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows the avatar when there is one', (tester) async {
    await _pump(
      tester,
      account.copyWith(avatarUrl: 'https://cdn.zedu.test/ada.png'),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, 'https://cdn.zedu.test/ada.png');
    expect(find.text('AL'), findsNothing);
  });

  testWidgets('shows the initials when the avatar fails to load', (
    tester,
  ) async {
    await _pump(
      tester,
      account.copyWith(avatarUrl: 'https://cdn.zedu.test/broken.png'),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final fallback = image.errorBuilder!(
      tester.element(find.byType(Image)),
      Exception('404'),
      null,
    );
    await tester.pumpWidget(buildTestMaterialApp(Scaffold(body: fallback)));

    expect(find.text('AL'), findsOneWidget);
  });

  testWidgets('treats a blank avatar link as no avatar', (tester) async {
    await _pump(tester, account.copyWith(avatarUrl: '   '));

    expect(find.text('AL'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('shows the saved username as the handle', (tester) async {
    await _pump(tester, account.copyWith(username: 'CountessAda'));

    // The header and the Personal details Username row, as on web.
    expect(find.text('@CountessAda'), findsNWidgets(2));
    expect(find.text('@adalovelace'), findsNothing);
  });

  testWidgets('trims the saved username', (tester) async {
    await _pump(tester, account.copyWith(username: '  ada_l '));

    expect(find.text('@ada_l'), findsNWidgets(2));
  });

  testWidgets('falls back to the name when there is no username', (
    tester,
  ) async {
    await _pump(tester, account);

    expect(find.text('@adalovelace'), findsOneWidget);
  });

  testWidgets('falls back to the name for a blank username', (tester) async {
    await _pump(tester, account.copyWith(username: '   '));

    expect(find.text('@adalovelace'), findsOneWidget);
  });

  testWidgets('binds handle text color to context.colors.textSecondary', (
    tester,
  ) async {
    BuildContext? sectionContext;
    await tester.pumpWidget(
      buildTestMaterialApp(
        Builder(
          builder: (context) {
            sectionContext = context;
            return Scaffold(
              body: SingleChildScrollView(
                child: AccountSection(
                  account: account.copyWith(username: 'CountessAda'),
                  isSaving: false,
                  onSave: (_, _) async => null,
                  onDelete: () async {},
                ),
              ),
            );
          },
        ),
      ),
    );

    final handleText = tester.widget<Text>(find.text('@CountessAda').first);
    expect(
      handleText.style?.color,
      equals(sectionContext!.colors.textSecondary),
    );
  });

  testWidgets('colours the initials placeholder with theme tokens', (
    tester,
  ) async {
    await _pump(tester, account);

    final initials = tester.widget<Text>(find.text('AL'));
    final box = tester.widget<Container>(
      find
          .ancestor(of: find.text('AL'), matching: find.byType(Container))
          .first,
    );

    expect(initials.style!.color, AppPalette.light.primary);
    expect(
      (box.decoration! as BoxDecoration).color,
      AppPalette.light.primaryBg,
    );
  });

  group('matches the web Account page (Ziki #12421)', () {
    Future<void> pumpFull(
      WidgetTester tester, {
      ProfileAccount? profile,
      UserStatus? status,
      VoidCallback? onEditStatus,
      Size size = const Size(1400, 1000),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AccountSection(
                account: profile ?? account,
                isSaving: false,
                onSave: (_, _) async => null,
                onDelete: () async {},
                status: status,
                onEditStatus: onEditStatus,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows the header, profile card and Personal details rows', (
      tester,
    ) async {
      await pumpFull(
        tester,
        profile: account.copyWith(
          displayName: 'Ada',
          username: 'ada',
          title: 'Engineer',
        ),
      );

      expect(find.text('Account'), findsOneWidget);
      expect(
        find.text('Manage how you appear to others and your sign-in details.'),
        findsOneWidget,
      );
      expect(find.text('Change photo'), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Personal details'), findsOneWidget);
      for (final label in [
        'Display name',
        'Username',
        'Title',
        'Email address',
        'Phone number',
        'Status',
        'Time zone',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Engineer'), findsOneWidget);
      expect(find.text('ada@zedu.test'), findsOneWidget);
      expect(find.text('(UTC+01:00) West Central Africa'), findsOneWidget);
      // Display name, Title, Phone number and Time zone are editable.
      expect(find.text('Edit'), findsNWidgets(4));
      expect(find.text('Your Account Information'), findsNothing);
    });

    testWidgets('shows "Not set" for empty fields and no Username row '
        'without a username', (tester) async {
      await pumpFull(tester);

      expect(find.text('Not set'), findsNWidgets(2)); // Title, Phone number
      expect(find.text('Username'), findsNothing);
      expect(find.text('No status set'), findsOneWidget);
      expect(find.text('Set a status'), findsNothing); // no handler given
    });

    testWidgets('the Status row shows the status and opens the status editor', (
      tester,
    ) async {
      var opened = 0;
      await pumpFull(
        tester,
        status: const UserStatus(emoji: '🌴', text: 'On leave'),
        onEditStatus: () => opened++,
      );

      expect(find.text('🌴 On leave'), findsOneWidget);
      await tester.tap(find.text('Update status'));
      expect(opened, 1);
    });

    testWidgets('Edit profile, Change photo and each Edit open the editor', (
      tester,
    ) async {
      await pumpFull(tester);

      for (final finder in [
        find.text('Edit profile'),
        find.text('Change photo'),
        find.byKey(const ValueKey('account_action_Title')),
        find.byKey(const ValueKey('account_action_Time zone')),
      ]) {
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(find.text('Edit your profile'), findsOneWidget);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Edit your profile'), findsNothing);
      }
    });

    testWidgets('lays out without overflow in a narrow window', (tester) async {
      await pumpFull(
        tester,
        profile: account.copyWith(
          displayName: 'A very long display name for a narrow window',
          username: 'a_rather_long_username_too',
        ),
        size: const Size(420, 1400),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Delete my account'), findsOneWidget);
    });
  });
}
