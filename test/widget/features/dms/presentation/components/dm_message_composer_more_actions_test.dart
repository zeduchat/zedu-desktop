import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

/// No channels, so the Channel tag button's # list has nothing to load.
class _NoChannels extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => const [];
}

class _FakeSecureStorageService extends Fake implements SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<String?> readData(String key) async => _values[key];

  @override
  Future<void> writeData(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> deleteValue(String key) async => _values.remove(key);
}

const _grouped = ['Attach file', 'Voice message', 'Channel tag', 'Divider'];

Future<void> _pumpComposer(WidgetTester tester, {double width = 1000}) async {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        channelProvider.overrideWith(_NoChannels.new),
        dmDraftStoreProvider.overrideWith(
          (ref) => DmDraftStore(
            _FakeSecureStorageService(),
            userId: 'user-1',
            orgId: 'org-1',
          ),
        ),
      ],
      child: buildTestMaterialApp(
        const Scaffold(
          body: DmMessageComposer(recipientName: 'Ada', channelId: 'dm-1'),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Runs [body], then empties the composer so its draft flush in `dispose`
/// has nothing to save when the test unmounts it.
void _composerTest(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  double width = 1000,
}) {
  testWidgets(description, (tester) async {
    await _pumpComposer(tester, width: width);
    await body(tester);
    tester.widget<EditableText>(find.byType(EditableText)).controller.clear();
    await tester.pump(const Duration(milliseconds: 300));
  });
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More actions'));
  await tester.pump();
}

void main() {
  group('DmMessageComposer plus menu', () {
    _composerTest('keeps emoji and mention visible and hides the rest', (
      tester,
    ) async {
      expect(find.byTooltip('Emoji (Ctrl/Cmd+Shift+E)'), findsOneWidget);
      expect(find.byTooltip('Mention someone'), findsOneWidget);
      expect(find.byTooltip('More actions'), findsOneWidget);
      for (final action in _grouped) {
        expect(find.byTooltip(action), findsNothing, reason: action);
      }
    });

    _composerTest('opens to show every grouped action and turns into close', (
      tester,
    ) async {
      await _openMenu(tester);

      for (final action in _grouped) {
        expect(find.byTooltip(action), findsOneWidget, reason: action);
      }
      expect(find.byTooltip('Close more actions'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byTooltip('Close more actions'),
          matching: find.byIcon(Icons.close),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Emoji (Ctrl/Cmd+Shift+E)'), findsOneWidget);
      expect(find.byTooltip('Mention someone'), findsOneWidget);
    });

    _composerTest('closes when the trigger is pressed again', (tester) async {
      await _openMenu(tester);
      await tester.tap(find.byTooltip('Close more actions'));
      await tester.pump();

      expect(find.byTooltip('More actions'), findsOneWidget);
      for (final action in _grouped) {
        expect(find.byTooltip(action), findsNothing, reason: action);
      }
    });

    _composerTest('picking an action runs it and closes the menu', (
      tester,
    ) async {
      await _openMenu(tester);
      await tester.tap(find.byTooltip('Channel tag'));
      await tester.pump();

      final controller = tester
          .widget<EditableText>(find.byType(EditableText))
          .controller;
      expect(controller.text, '#');
      expect(find.byTooltip('Channel tag'), findsNothing);
      expect(find.byTooltip('More actions'), findsOneWidget);
    });

    _composerTest('Escape in the message box closes the menu', (tester) async {
      await _openMenu(tester);
      expect(find.byTooltip('Divider'), findsOneWidget);
      // Typing focus goes back to the message box with the menu still open.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(find.byTooltip('Divider'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byTooltip('Divider'), findsNothing);
      expect(find.byTooltip('More actions'), findsOneWidget);
    });

    _composerTest(
      'keeps the send button visible with the menu open at a narrow width',
      (tester) async {
        await _openMenu(tester);

        expect(tester.takeException(), isNull);
        final send = find.byIcon(Icons.send_rounded);
        expect(send, findsOneWidget);
        final sendRect = tester.getRect(send);
        expect(sendRect.right, lessThanOrEqualTo(480));
        expect(sendRect.left, greaterThan(0));
      },
      width: 480,
    );
  });
}
