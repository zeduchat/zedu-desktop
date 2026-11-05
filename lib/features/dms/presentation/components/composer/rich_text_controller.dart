import 'package:zedu/core/core.dart';

import 'inline_markdown.dart';

class RichTextController extends TextEditingController {
  RichTextController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return buildInlineMarkdownSpan(
      text,
      style ?? const TextStyle(),
      keepMarkers: true,
    );
  }
}
