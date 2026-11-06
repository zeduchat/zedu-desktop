import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockAppLinks extends Mock implements AppLinks {}

class _SignedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

class _SignedOutAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _FakeDmListNotifier extends DmListNotifier {
  _FakeDmListNotifier(this.conversations);

  final List<DmConversation> conversations;

  @override
  Future<List<DmConversation>> build() async => conversations;
}

GoRouter _buildRouter() => GoRouter(
  initialLocation: AppRouter.login,
  navigatorKey: AppRouter.navigatorKey,
  routes: [
    GoRoute(
      path: AppRouter.login,
      builder: (context, state) => const Scaffold(body: Text('Login screen')),
    ),
    GoRoute(
      path: AppRouter.home,
      builder: (context, state) => const Scaffold(body: Text('Home screen')),
    ),
  ],
);

void main() {
  group('ChatDeepLinkListener', () {
    late MockAppLinks mockAppLinks;
    late StreamController<Uri> linkController;

    setUp(() {
      mockAppLinks = MockAppLinks();
      linkController = StreamController<Uri>.broadcast();

      when(
        () => mockAppLinks.uriLinkStream,
      ).thenAnswer((_) => linkController.stream);
      when(() => mockAppLinks.getInitialLink()).thenAnswer((_) async => null);
    });

    tearDown(() async {
      await linkController.close();
    });

    Future<void> pumpListener(
      WidgetTester tester, {
      required AuthNotifier authNotifier,
      required List<DmConversation> conversations,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(() => authNotifier),
            dmListProvider.overrideWith(
              () => _FakeDmListNotifier(conversations),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: _buildRouter(),
            builder: (context, child) => ChatDeepLinkListener(
              appLinks: mockAppLinks,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('opens the conversation a valid initial link points at', (
      tester,
    ) async {
      when(
        () => mockAppLinks.getInitialLink(),
      ).thenAnswer((_) async => Uri.parse('zedu://chat/ch-1?message=m-9'));

      await pumpListener(
        tester,
        authNotifier: _SignedInAuthNotifier(),
        conversations: [
          DmConversation(
            channelId: 'ch-1',
            username: 'Ada',
            participantId: 'u-2',
            previewMessage: '',
            unreadCount: 0,
          ),
        ],
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );

      expect(find.text('Home screen'), findsOneWidget);
      expect(container.read(homeSidebarProvider), HomeSidebarType.dms);
      expect(container.read(selectedDmProvider)?.channelId, 'ch-1');
      final pending = container.read(pendingMessageJumpProvider);
      expect(pending?.channelId, 'ch-1');
      expect(pending?.messageId, 'm-9');
    });

    testWidgets('creates a minimal conversation when the list lacks it', (
      tester,
    ) async {
      when(
        () => mockAppLinks.getInitialLink(),
      ).thenAnswer((_) async => Uri.parse('zedu://chat/new-ch'));

      await pumpListener(
        tester,
        authNotifier: _SignedInAuthNotifier(),
        conversations: const [],
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );

      expect(find.text('Home screen'), findsOneWidget);
      expect(container.read(selectedDmProvider)?.channelId, 'new-ch');
    });

    testWidgets('ignores links while signed out', (tester) async {
      when(
        () => mockAppLinks.getInitialLink(),
      ).thenAnswer((_) async => Uri.parse('zedu://chat/ch-1'));

      await pumpListener(
        tester,
        authNotifier: _SignedOutAuthNotifier(),
        conversations: const [],
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );

      expect(find.text('Login screen'), findsOneWidget);
      expect(container.read(selectedDmProvider), isNull);
    });

    testWidgets('ignores links that are not chat links', (tester) async {
      when(
        () => mockAppLinks.getInitialLink(),
      ).thenAnswer((_) async => Uri.parse('zedu://auth/magick-link/verify'));

      await pumpListener(
        tester,
        authNotifier: _SignedInAuthNotifier(),
        conversations: const [],
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );

      expect(find.text('Login screen'), findsOneWidget);
      expect(container.read(selectedDmProvider), isNull);
    });

    testWidgets('opens the conversation for a link arriving while running', (
      tester,
    ) async {
      await pumpListener(
        tester,
        authNotifier: _SignedInAuthNotifier(),
        conversations: [
          DmConversation(
            channelId: 'ch-2',
            username: 'Grace',
            participantId: 'u-3',
            previewMessage: '',
            unreadCount: 0,
          ),
        ],
      );
      expect(find.text('Login screen'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );

      linkController.add(Uri.parse('zedu://chat/ch-2?message=m-4'));
      await tester.pumpAndSettle();

      expect(find.text('Home screen'), findsOneWidget);
      expect(container.read(selectedDmProvider)?.channelId, 'ch-2');
      final pending = container.read(pendingMessageJumpProvider);
      expect(pending?.messageId, 'm-4');
    });
  });
}
