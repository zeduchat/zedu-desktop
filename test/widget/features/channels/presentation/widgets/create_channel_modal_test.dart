import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeChannelNotifier extends ChannelNotifier {
  Result<Channel> result = const Failure<Channel>(
    ApiFailure(message: 'Channel name already exists'),
  );
  int createCalls = 0;

  @override
  Future<List<Channel>> build() async => const [];

  @override
  Future<Result<Channel>> createChannel({
    required String name,
    required String description,
    required bool isPrivate,
    String? topic,
  }) async {
    createCalls++;
    return result;
  }
}

void main() {
  group('CreateChannelModal', () {
    late _FakeChannelNotifier notifier;

    Future<void> openModal(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      notifier = _FakeChannelNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [channelProvider.overrideWith(() => notifier)],
          child: buildTestMaterialApp(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const CreateChannelModal(),
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

    Future<void> submit(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).first, 'general');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
    }

    // AppToastService auto-dismisses on a 4s timer; let it fire before the
    // test ends so no timer is left pending.
    Future<void> drainToastTimer(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the server message when creating fails', (tester) async {
      await openModal(tester);

      await submit(tester);

      expect(find.text('Channel name already exists'), findsOneWidget);
      expect(find.text('Create a channel'), findsOneWidget);
    });

    testWidgets('does not show an old error when opened again', (tester) async {
      await openModal(tester);
      await submit(tester);
      expect(find.text('Channel name already exists'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Create a channel'), findsOneWidget);
      expect(find.text('Channel name already exists'), findsNothing);
    });

    testWidgets('does not show a failed channel load as a create error', (
      tester,
    ) async {
      await openModal(tester);
      // Build the provider first, then fail its channel load.
      ProviderScope.containerOf(
        tester.element(find.byType(CreateChannelModal)),
      ).read(channelProvider);
      await tester.pumpAndSettle();
      notifier.state = AsyncError<List<Channel>>(
        const ApiFailure(message: 'Could not load channels'),
        StackTrace.current,
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load channels'), findsNothing);
    });

    testWidgets('closes the dialog when the channel is created', (
      tester,
    ) async {
      await openModal(tester);
      notifier.result = Success<Channel>(
        Channel(
          id: 'c1',
          name: 'general',
          description: '',
          organisationId: 'org-1',
          ownerId: 'user-1',
        ),
      );

      await submit(tester);

      expect(find.text('Create a channel'), findsNothing);
      await drainToastTimer(tester);
    });

    testWidgets('confirms the creation with a success toast', (tester) async {
      await openModal(tester);
      notifier.result = Success<Channel>(
        Channel(
          id: 'c1',
          name: 'general',
          description: '',
          organisationId: 'org-1',
          ownerId: 'user-1',
        ),
      );

      await submit(tester);

      expect(find.text('Channel created'), findsOneWidget);
      await drainToastTimer(tester);
    });

    testWidgets('asks for a name when Create is tapped with none', (
      tester,
    ) async {
      await openModal(tester);

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Channel name is required'), findsOneWidget);
      expect(notifier.createCalls, 0);
    });

    testWidgets('treats a name of only spaces as empty', (tester) async {
      await openModal(tester);

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Channel name is required'), findsOneWidget);
      expect(notifier.createCalls, 0);
    });

    testWidgets('clears the name error once a name is typed', (tester) async {
      await openModal(tester);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'general');
      await tester.pump();

      expect(find.text('Channel name is required'), findsNothing);
    });
  });
}
