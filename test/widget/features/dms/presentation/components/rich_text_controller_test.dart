import 'package:zedu/features/dms/presentation/components/composer/composer.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  for (final content in ['**hello**', '~~hello~~', '*hello*', 'plain']) {
    testWidgets('inline code keeps $content literal and preserves source', (
      tester,
    ) async {
      final source = '`$content`';
      final controller = RichTextController(text: source);
      addTearDown(controller.dispose);
      late TextSpan span;
      await tester.pumpWidget(
        buildTestMaterialApp(
          Builder(
            builder: (context) {
              span = controller.buildTextSpan(
                context: context,
                withComposing: false,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(span.toPlainText(), source);
      final token = span.children!.single as TextSpan;
      final inner = token.children![1] as TextSpan;
      expect(inner.text, content);
      expect(inner.style!.fontFamily, 'monospace');
      expect(inner.style!.fontWeight, isNot(FontWeight.bold));
      expect(inner.style!.decoration, isNot(TextDecoration.lineThrough));
    });
  }

  testWidgets('mixed formatting keeps outer styles and source offsets', (
    tester,
  ) async {
    const source = 'before **bold** *italic* ~~strike~~ `**code**` after';
    final controller = RichTextController(text: source);
    addTearDown(controller.dispose);
    late TextSpan span;
    await tester.pumpWidget(
      buildTestMaterialApp(
        Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 16),
              withComposing: false,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(span.toPlainText(), source);
    final tokens = span.children!
        .cast<TextSpan>()
        .where((child) => child.children != null)
        .map((child) => child.children![1] as TextSpan)
        .toList();
    expect(tokens.map((token) => token.text), [
      'bold',
      'italic',
      'strike',
      '**code**',
    ]);
    expect(tokens[0].style!.fontWeight, FontWeight.bold);
    expect(tokens[1].style!.fontStyle, FontStyle.italic);
    expect(tokens[2].style!.decoration, TextDecoration.lineThrough);
    expect(tokens[3].style!.fontFamily, 'monospace');
    expect(tokens.every((token) => token.style!.fontSize == 16), isTrue);
  });
}
