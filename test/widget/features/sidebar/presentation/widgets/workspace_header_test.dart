import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class FakeWorkspaceNotifier extends WorkspaceNotifier {
  static const _workspace = Workspace(
    id: '1',
    name: 'commabuster',
    avatar: '',
    channelsCount: 12,
  );

  @override
  WorkspaceState build() => const WorkspaceState(
    workspaces: [_workspace],
    selectedWorkspace: _workspace,
  );
}

Widget buildHeaderUnderTest() {
  return ProviderScope(
    overrides: [workspaceProvider.overrideWith(FakeWorkspaceNotifier.new)],
    child: MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.only(left: 100, top: 40),
              child: Container(
                color: Colors.indigo,
                child: const WorkspaceSwitcherHeader(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// Tests render text in a very wide placeholder font, which overflows the
// menu footer. A smaller text scale keeps the layout checks meaningful.
Future<void> useTestWindow(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1024));
  tester.platformDispatcher.textScaleFactorTestValue = 0.5;
  addTearDown(() {
    tester.binding.setSurfaceSize(null);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

void main() {
  group('WorkspaceSwitcherHeader', () {
    testWidgets('opens the menu under the name and flips the arrow', (
      tester,
    ) async {
      await useTestWindow(tester);

      await tester.pumpWidget(buildHeaderUnderTest());
      await tester.pump();

      final headerRect = tester.getRect(find.byType(WorkspaceSwitcherHeader));
      final nameRect = tester.getRect(find.text('commabuster'));
      expect(
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
        0,
      );

      await tester.tap(find.text('commabuster'));
      await tester.pumpAndSettle();

      final menuRect = tester.getRect(find.byType(WorkspaceSwitcherList));
      expect(find.text('Switch Workspaces'), findsOneWidget);
      expect(menuRect.left, nameRect.left - 8);
      expect(menuRect.top, headerRect.bottom + 10);
      expect(
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
        0.5,
      );
    });

    testWidgets('closes when tapping outside and flips the arrow back', (
      tester,
    ) async {
      await useTestWindow(tester);

      await tester.pumpWidget(buildHeaderUnderTest());
      await tester.pump();

      await tester.tap(find.text('commabuster'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceSwitcherList), findsOneWidget);

      await tester.tapAt(const Offset(1300, 900));
      await tester.pumpAndSettle();

      expect(find.byType(WorkspaceSwitcherList), findsNothing);
      expect(
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
        0,
      );
    });

    testWidgets(
      'scrolls the whole menu in a short window instead of overflowing',
      (tester) async {
        await useTestWindow(tester);
        // A short window: MediaQuery reads the view size, which sets the cap.
        await tester.binding.setSurfaceSize(const Size(1440, 260));
        tester.view.physicalSize = const Size(1440, 260);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildHeaderUnderTest());
        await tester.pump();

        await tester.tap(find.text('commabuster'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final footer = find.text('Add a new organization');
        await tester.scrollUntilVisible(
          footer,
          50,
          scrollable: find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        // The footer is now inside the visible, height-capped menu.
        final menuRect = tester.getRect(find.byType(SingleChildScrollView));
        final footerRect = tester.getRect(footer);
        expect(footerRect.top, greaterThanOrEqualTo(menuRect.top));
        expect(footerRect.bottom, lessThanOrEqualTo(menuRect.bottom));
        expect(menuRect.bottom, lessThanOrEqualTo(260));
      },
    );

    testWidgets(
      'enforces minimum clamped maxHeight of 120 on extremely low vertical resolutions without crashing',
      (tester) async {
        await useTestWindow(tester);
        await tester.binding.setSurfaceSize(const Size(1440, 130));
        tester.view.physicalSize = const Size(1440, 130);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildHeaderUnderTest());
        await tester.pump();

        await tester.tap(find.text('commabuster'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(WorkspaceSwitcherList), findsOneWidget);

        final constrainedBoxes = tester.widgetList<ConstrainedBox>(
          find.descendant(
            of: find.byType(Stack),
            matching: find.byType(ConstrainedBox),
          ),
        );
        final menuBox = constrainedBoxes.firstWhere(
          (box) => box.constraints.maxHeight == 120.0,
        );
        expect(menuBox.constraints.maxHeight, 120.0);
      },
    );

    testWidgets('plus button opens the New Group Chat page', (tester) async {
      await useTestWindow(tester);
      await tester.pumpWidget(buildHeaderUnderTest());
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorkspaceSwitcherHeader)),
      );
      expect(
        container.read(activeChatProvider).type,
        isNot(ActiveChatType.newGroupChat),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(
        container.read(activeChatProvider).type,
        ActiveChatType.newGroupChat,
      );
    });

    testWidgets('plus button has a tooltip for accessibility', (tester) async {
      await useTestWindow(tester);
      await tester.pumpWidget(buildHeaderUnderTest());
      await tester.pump();

      final iconButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add),
      );
      expect(iconButton.tooltip, 'New conversation');
    });
  });
}
