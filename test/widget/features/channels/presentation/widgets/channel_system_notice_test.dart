import '../../../../../helpers/helpers.dart';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

void main() {
  final notice = ChannelMessage.fromJson({
    'type': 'system',
    'message':
        '<p><span class="mention" data-type="mention" data-id="u-1" '
        'data-label="mimi">@mimi</span> joined this channel</p>',
  });

  TextSpan nameSpan(WidgetTester tester) {
    final rich = tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('joined'),
      ),
    );
    TextSpan? found;
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == 'mimi') found = span;
      return found == null;
    });
    return found!;
  }

  testWidgets('tapping a name passes the person on', (tester) async {
    final tapped = <ChannelNoticePart>[];
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: ChannelSystemNotice(message: notice, onMentionTap: tapped.add),
        ),
      ),
    );

    (nameSpan(tester).recognizer! as TapGestureRecognizer).onTap!();

    expect(tapped.single.userId, 'u-1');
    expect(tapped.single.text, 'mimi');
  });

  testWidgets('a name turns the primary colour on hover', (tester) async {
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: ChannelSystemNotice(message: notice, onMentionTap: (_) {}),
        ),
      ),
    );
    expect(nameSpan(tester).style?.color, isNot(AppPalette.light.primary));

    nameSpan(tester).onEnter!(const PointerEnterEvent());
    await tester.pump();

    expect(nameSpan(tester).style?.color, AppPalette.light.primary);
  });
}
