import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.user);

  final User user;

  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: user);
}

User _user({String avatarUrl = ''}) => User(
  id: 'user-1',
  firstName: 'Arnold',
  lastName: 'Nyamongo',
  email: 'arnold@example.com',
  phone: '',
  username: 'arnold',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime.utc(2026, 11, 4),
  currentOrg: 'org-1',
  currentOrganisationSlug: 'zedu',
  avatarUrl: avatarUrl,
  defaultAvatarUrl: '',
);

Future<void> _pumpDialog(WidgetTester tester, User user) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
        orgCreditBalanceProvider.overrideWithValue(0),
      ],
      child: const MaterialApp(home: Scaffold(body: UserMenuDialog())),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('falls back to the user initials when there is no avatar', (
    tester,
  ) async {
    await _pumpDialog(tester, _user());

    expect(find.text('AN'), findsOneWidget);
  });

  testWidgets('renders the user avatar when a URL is available', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      _user(avatarUrl: 'https://cdn.example.com/a.png'),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, 'https://cdn.example.com/a.png');
  });
}
