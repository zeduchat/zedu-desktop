import 'package:zedu/core/core.dart';
import '../../../helpers/helpers.dart';

class _FlakyWidget extends StatelessWidget {
  const _FlakyWidget({required this.shouldThrow});

  final bool Function() shouldThrow;

  @override
  Widget build(BuildContext context) {
    if (shouldThrow()) throw StateError('unexpected payload');
    return const Text('Loaded');
  }
}

void main() {
  group('Global error handling', () {
    test('installGlobalErrorHandlers installs all three handlers', () {
      final originalOnError = FlutterError.onError;
      final originalDispatcherOnError = PlatformDispatcher.instance.onError;
      final originalBuilder = ErrorWidget.builder;
      addTearDown(() {
        FlutterError.onError = originalOnError;
        PlatformDispatcher.instance.onError = originalDispatcherOnError;
        ErrorWidget.builder = originalBuilder;
      });

      installGlobalErrorHandlers();

      expect(FlutterError.onError, isNot(same(originalOnError)));
      expect(PlatformDispatcher.instance.onError, isNotNull);
      expect(
        PlatformDispatcher.instance.onError!(StateError('x'), StackTrace.empty),
        isTrue,
      );
      final built = ErrorWidget.builder(
        FlutterErrorDetails(exception: StateError('x')),
      );
      expect(built, isA<AppErrorWidget>());
    });

    testWidgets(
      'a build exception shows AppErrorWidget and Try again recovers',
      (tester) async {
        final originalBuilder = ErrorWidget.builder;
        ErrorWidget.builder = (details) => AppErrorWidget(details: details);

        var fail = true;
        await tester.pumpWidget(
          buildTestMaterialApp(
            Scaffold(
              body: Column(
                children: [
                  const Text('Sidebar still here'),
                  Expanded(child: _FlakyWidget(shouldThrow: () => fail)),
                ],
              ),
            ),
          ),
        );

        expect(tester.takeException(), isA<StateError>());
        expect(find.byType(AppErrorWidget), findsOneWidget);
        expect(find.text('Something went wrong here.'), findsOneWidget);
        expect(find.text('Sidebar still here'), findsOneWidget);
        expect(find.text('Back to home'), findsOneWidget);

        fail = false;
        await tester.tap(find.text('Try again'));
        await tester.pump();

        expect(find.byType(AppErrorWidget), findsNothing);
        expect(find.text('Loaded'), findsOneWidget);

        // The test binding requires the builder to be restored in the body.
        ErrorWidget.builder = originalBuilder;
      },
    );
  });
}
