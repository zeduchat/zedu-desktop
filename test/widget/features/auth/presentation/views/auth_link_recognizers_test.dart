import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

Widget _buildView(Widget view) {
  return ProviderScope(
    overrides: [authNotifierProvider.overrideWith(() => _FakeAuthNotifier())],
    child: MaterialApp(home: view),
  );
}

List<GestureRecognizer> _linkRecognizers(WidgetTester tester) {
  final recognizers = <GestureRecognizer>[];
  for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
    text.text.visitChildren((span) {
      if (span is TextSpan && span.recognizer != null) {
        recognizers.add(span.recognizer!);
      }
      return true;
    });
  }
  return recognizers;
}

void main() {
  const views = <String, (Widget, int)>{
    'ForgotPasswordView': (ForgotPasswordView(), 1),
    'LoginView': (LoginView(), 1),
    'MagicLinkRequestView': (MagicLinkRequestView(), 1),
    'SignUpView': (SignUpView(), 3),
  };

  for (final MapEntry(key: name, value: (view, count)) in views.entries) {
    testWidgets('$name keeps its link recognizers and disposes them', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final disposed = <Object>{};
      void onEvent(ObjectEvent event) {
        if (event is ObjectDisposed) disposed.add(event.object);
      }

      FlutterMemoryAllocations.instance.addListener(onEvent);
      addTearDown(
        () => FlutterMemoryAllocations.instance.removeListener(onEvent),
      );

      await tester.pumpWidget(_buildView(view));
      await tester.pump();
      final links = _linkRecognizers(tester);
      expect(links, hasLength(count));

      await tester.pumpWidget(_buildView(view));
      await tester.pump();
      expect(_linkRecognizers(tester), links);

      await tester.pumpWidget(const SizedBox());
      expect(disposed, containsAll(links));
    });
  }
}
