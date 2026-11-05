import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';

class _MockWindowManager extends Mock implements WindowManager {}

class _MockStorage extends Mock implements SecureStorageService {}

class _FakeWindowListener extends Fake implements WindowListener {}

const _key = 'window_bounds';
const _screen = Rect.fromLTWH(0, 0, 1920, 1040);
const _saved = Rect.fromLTWH(100, 80, 1200, 700);

void main() {
  setUpAll(() {
    registerFallbackValue(Size.zero);
    registerFallbackValue(Rect.zero);
    registerFallbackValue(_FakeWindowListener());
  });

  late _MockWindowManager window;
  late _MockStorage storage;

  WindowBoundsController controller({List<Rect> displays = const [_screen]}) {
    return WindowBoundsController(
      window: window,
      storage: storage,
      displayAreas: () async => displays,
      saveDelay: Duration.zero,
    );
  }

  void stubSaved(String? value) {
    when(() => storage.readData(_key)).thenAnswer((_) async => value);
  }

  setUp(() {
    window = _MockWindowManager();
    storage = _MockStorage();
    when(() => window.setMinimumSize(any())).thenAnswer((_) async {});
    when(() => window.setBounds(any())).thenAnswer((_) async {});
    when(() => window.maximize()).thenAnswer((_) async {});
    when(() => window.addListener(any())).thenReturn(null);
    when(() => window.isMinimized()).thenAnswer((_) async => false);
    when(() => window.isMaximized()).thenAnswer((_) async => false);
    when(() => window.getBounds()).thenAnswer((_) async => _saved);
    when(() => storage.writeData(any(), any())).thenAnswer((_) async {});
  });

  group('restore', () {
    test('always sets the minimum size', () async {
      stubSaved(null);

      await controller().restore();

      verify(() => window.setMinimumSize(kMinimumWindowSize)).called(1);
      verifyNever(() => window.setBounds(any()));
    });

    test('applies saved bounds that are on a display', () async {
      stubSaved(
        const SavedWindowBounds(rect: _saved, isMaximized: false).toJson(),
      );

      await controller().restore();

      verify(() => window.setBounds(_saved)).called(1);
      verifyNever(() => window.maximize());
    });

    test('maximizes again when it was closed maximized', () async {
      stubSaved(
        const SavedWindowBounds(rect: _saved, isMaximized: true).toJson(),
      );

      await controller().restore();

      verify(() => window.setBounds(_saved)).called(1);
      verify(() => window.maximize()).called(1);
    });

    test('keeps the default when the saved monitor is gone', () async {
      const onSecondMonitor = Rect.fromLTWH(2500, 100, 1200, 700);
      stubSaved(
        const SavedWindowBounds(
          rect: onSecondMonitor,
          isMaximized: false,
        ).toJson(),
      );

      await controller().restore();

      verifyNever(() => window.setBounds(any()));
    });

    test('ignores saved data it cannot read', () async {
      stubSaved('{"x": "not a number"}');

      await controller().restore();

      verifyNever(() => window.setBounds(any()));
    });

    test('still listens when restoring fails', () async {
      when(() => storage.readData(_key)).thenThrow(Exception('locked'));

      await controller().restore();

      verify(() => window.addListener(any())).called(1);
    });
  });

  group('isWindowReachable', () {
    test('accepts a window on a second display', () {
      const second = Rect.fromLTWH(1920, 0, 1920, 1040);

      expect(
        isWindowReachable(const Rect.fromLTWH(2000, 100, 1200, 700), const [
          _screen,
          second,
        ]),
        isTrue,
      );
    });

    test('rejects a window whose title bar is above the display', () {
      expect(
        isWindowReachable(const Rect.fromLTWH(100, -500, 1200, 700), const [
          _screen,
        ]),
        isFalse,
      );
    });

    test('rejects a window with only a sliver on the display', () {
      expect(
        isWindowReachable(const Rect.fromLTWH(1880, 100, 1200, 700), const [
          _screen,
        ]),
        isFalse,
      );
    });
  });

  group('saving', () {
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('stores the bounds after a resize', () async {
      controller().onWindowResize();
      await settle();
      await settle();

      final saved = SavedWindowBounds.tryParse(
        verify(() => storage.writeData(_key, captureAny())).captured.single
            as String,
      );
      expect(saved?.rect, _saved);
      expect(saved?.isMaximized, isFalse);
    });

    test('does not store a minimized window', () async {
      when(() => window.isMinimized()).thenAnswer((_) async => true);

      controller().onWindowMove();
      await settle();
      await settle();

      verifyNever(() => storage.writeData(any(), any()));
    });

    test('keeps the normal size while maximized', () async {
      stubSaved(
        const SavedWindowBounds(rect: _saved, isMaximized: false).toJson(),
      );
      final bounds = controller();
      await bounds.restore();
      when(() => window.isMaximized()).thenAnswer((_) async => true);
      when(() => window.getBounds()).thenAnswer((_) async => _screen);

      bounds.onWindowMaximize();
      await settle();
      await settle();

      final saved = SavedWindowBounds.tryParse(
        verify(() => storage.writeData(_key, captureAny())).captured.single
            as String,
      );
      expect(saved?.rect, _saved);
      expect(saved?.isMaximized, isTrue);
    });
  });
}
