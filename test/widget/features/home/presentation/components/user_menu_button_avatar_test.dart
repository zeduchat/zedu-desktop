import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.user);

  final User user;

  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: user);
}

User _user({String avatarUrl = ''}) => User(
  id: 'user-1',
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: 'ada@zedu.test',
  phone: '',
  username: 'ada',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime.utc(2026, 11, 26),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'zedu',
  avatarUrl: avatarUrl,
  defaultAvatarUrl: '',
);

Future<void> _pumpInRail(WidgetTester tester, User user) async {
  final container = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
    ],
  );
  addTearDown(container.dispose);
  // The rail only shows once the session exists.
  container.read(authNotifierProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              // The rail's width less its 1 px border.
              width: AppSidebarRail.width - 1,
              child: Center(child: UserMenuButton()),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('UserMenuButton avatar (Ziki #12421)', () {
    testWidgets('shows the signed-in user\'s photo', (tester) async {
      await _pumpInRail(
        tester,
        _user(avatarUrl: 'https://cdn.zedu.test/ada.png'),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as NetworkImage).url,
        'https://cdn.zedu.test/ada.png',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows initials when there is no photo', (tester) async {
      await _pumpInRail(tester, _user());

      expect(find.text('AL'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('fits inside the rail without overflowing', (tester) async {
      await _pumpInRail(tester, _user());

      final size = tester.getSize(
        find.byKey(const ValueKey('user_menu_button_avatar')),
      );
      expect(size.width, lessThan(AppSidebarRail.width - 1));
      expect(tester.takeException(), isNull);
    });
  });
}
