import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zedu/core/window/window_startup.dart';

class _MockWindowManager extends Mock implements WindowManager {}

void main() {
  late _MockWindowManager window;
  late VoidCallback ready;

  setUp(() {
    window = _MockWindowManager();
    when(() => window.waitUntilReadyToShow(any(), any())).thenAnswer((
      call,
    ) async {
      ready = call.positionalArguments[1] as VoidCallback;
    });
    when(() => window.show()).thenAnswer((_) async {});
    when(() => window.focus()).thenAnswer((_) async {});
  });

  test('does not show the window before it is ready', () {
    showWindowWhenReady(window);

    verify(() => window.waitUntilReadyToShow(any(), any())).called(1);
    verifyNever(() => window.show());
    verifyNever(() => window.focus());
  });

  test('shows and then focuses the window once it is ready', () async {
    showWindowWhenReady(window);

    ready();
    await pumpEventQueue();

    verifyInOrder([() => window.show(), () => window.focus()]);
  });
}
