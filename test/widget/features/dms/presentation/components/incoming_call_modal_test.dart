import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _IncomingCallNotifier extends ActiveCallNotifier {
  _IncomingCallNotifier(super.ref, this.remoteUserName);

  final String? remoteUserName;

  @override
  ActiveCallState get state => ActiveCallState(
    status: CallStatus.incoming,
    remoteUserName: remoteUserName,
  );
}

Future<void> _pumpModal(WidgetTester tester, String? remoteUserName) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeCallProvider.overrideWith(
          (ref) => _IncomingCallNotifier(ref, remoteUserName),
        ),
      ],
      child: buildTestMaterialApp(
        const Scaffold(body: Stack(children: [IncomingCallModal()])),
      ),
    ),
  );
}

String _avatarInitial(WidgetTester tester) {
  final avatar = find.byType(CircleAvatar);
  final text = find.descendant(of: avatar, matching: find.byType(Text));
  return tester.widget<Text>(text).data!;
}

void main() {
  group('IncomingCallModal avatar initial', () {
    testWidgets('capitalises the first letter', (tester) async {
      await _pumpModal(tester, 'ada');

      expect(_avatarInitial(tester), 'A');
    });

    testWidgets('keeps an emoji at the start of the name whole', (
      tester,
    ) async {
      await _pumpModal(tester, '🎧 Alex');

      expect(_avatarInitial(tester), '🎧');
    });

    testWidgets('ignores spaces before the name', (tester) async {
      await _pumpModal(tester, '  ada');

      expect(_avatarInitial(tester), 'A');
    });

    testWidgets('shows a question mark for a blank name', (tester) async {
      await _pumpModal(tester, '   ');

      expect(_avatarInitial(tester), '?');
    });

    testWidgets('shows a question mark for no name', (tester) async {
      await _pumpModal(tester, null);

      expect(_avatarInitial(tester), '?');
    });
  });
}
