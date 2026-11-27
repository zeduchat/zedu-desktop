import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';

class _MockWindowManager extends Mock implements WindowManager {}

class _MockStorage extends Mock implements SecureStorageService {}

class _FakeRegistrar implements SystemHotkeyRegistrar {
  final registered = <HotKey>[];
  final pressed = <void Function()>[];
  var failNextRegister = false;
  var failRegisterCount = 0;
  var failNextUnregister = false;
  var unregisterCount = 0;

  @override
  Future<void> register(
    HotKey hotKey, {
    required void Function() onPressed,
  }) async {
    if (failNextRegister) {
      failNextRegister = false;
      throw Exception('already registered');
    }
    if (failRegisterCount > 0) {
      failRegisterCount--;
      throw Exception('already registered');
    }
    registered.removeWhere((key) => key.identifier == hotKey.identifier);
    registered.add(hotKey);
    pressed.add(onPressed);
  }

  @override
  Future<void> unregister(HotKey hotKey) async {
    if (failNextUnregister) {
      failNextUnregister = false;
      throw Exception('could not unregister');
    }
    unregisterCount++;
    registered.removeWhere((key) => key.identifier == hotKey.identifier);
  }
}

void main() {
  late _MockWindowManager window;
  late _MockStorage storage;
  late _FakeRegistrar registrar;

  final defaultBinding = HotkeyBinding.defaultFor(TargetPlatform.linux);

  WindowHotkeyController controller() => WindowHotkeyController(
    window: window,
    storage: storage,
    registrar: registrar,
    defaultBinding: defaultBinding,
  );

  setUpAll(() {
    registerFallbackValue(
      HotKey(key: LogicalKeyboardKey.keyA, identifier: 'fallback'),
    );
  });

  setUp(() {
    window = _MockWindowManager();
    storage = _MockStorage();
    registrar = _FakeRegistrar();
    when(
      () => storage.readData(kShowHideHotkeyStorageKey),
    ).thenAnswer((_) async => null);
    when(() => storage.writeData(any(), any())).thenAnswer((_) async {});
    when(() => window.isMinimized()).thenAnswer((_) async => false);
    when(() => window.isVisible()).thenAnswer((_) async => false);
    when(() => window.isFocused()).thenAnswer((_) async => false);
    when(() => window.show()).thenAnswer((_) async {});
    when(() => window.focus()).thenAnswer((_) async {});
    when(() => window.hide()).thenAnswer((_) async {});
    when(() => window.restore()).thenAnswer((_) async {});
  });

  group('HotkeyBinding', () {
    test('uses Cmd+Shift+Z on macOS and Ctrl+Shift+Z elsewhere', () {
      final mac = HotkeyBinding.defaultFor(TargetPlatform.macOS);
      final linux = HotkeyBinding.defaultFor(TargetPlatform.linux);

      expect(mac.key, LogicalKeyboardKey.keyZ);
      expect(mac.modifiers, {HotKeyModifier.meta, HotKeyModifier.shift});
      expect(linux.modifiers, {HotKeyModifier.control, HotKeyModifier.shift});
    });

    test('requires a Cmd, Ctrl or Alt modifier', () {
      final shiftOnly = HotkeyBinding(
        modifiers: const {HotKeyModifier.shift},
        key: LogicalKeyboardKey.keyZ,
      );
      final ctrl = HotkeyBinding(
        modifiers: const {HotKeyModifier.control},
        key: LogicalKeyboardKey.keyJ,
      );

      expect(shiftOnly.isValid, isFalse);
      expect(ctrl.isValid, isTrue);
    });

    test('rejects a bare modifier or Escape as the key', () {
      expect(
        HotkeyBinding(
          modifiers: const {HotKeyModifier.control},
          key: LogicalKeyboardKey.controlLeft,
        ).isValid,
        isFalse,
      );
      expect(
        HotkeyBinding(
          modifiers: const {HotKeyModifier.control},
          key: LogicalKeyboardKey.escape,
        ).isValid,
        isFalse,
      );
    });

    test('round-trips through JSON', () {
      final binding = HotkeyBinding(
        modifiers: const {HotKeyModifier.meta, HotKeyModifier.shift},
        key: LogicalKeyboardKey.keyJ,
      );

      final parsed = HotkeyBinding.tryParse(binding.toJson());

      expect(parsed, binding);
    });

    test('returns null for missing or broken values', () {
      expect(HotkeyBinding.tryParse(null), isNull);
      expect(HotkeyBinding.tryParse(''), isNull);
      expect(HotkeyBinding.tryParse('not json'), isNull);
      expect(HotkeyBinding.tryParse('{"modifiers": []}'), isNull);
      expect(
        HotkeyBinding.tryParse('{"modifiers": ["shift"], "keyId": 92}'),
        isNull,
      );
    });

    test('labels the chord with readable key names', () {
      const binding = HotkeyBinding(
        modifiers: {HotKeyModifier.control, HotKeyModifier.shift},
        key: LogicalKeyboardKey.keyZ,
      );

      expect(binding.label, 'Ctrl + Shift + Z');
    });
  });

  group('start', () {
    test('registers the default shortcut when nothing is saved', () async {
      await controller().start();

      expect(registrar.registered.single.modifiers, defaultBinding.modifiers);
      expect(registrar.registered.single.key, LogicalKeyboardKey.keyZ);
      expect(registrar.registered.single.scope, HotKeyScope.system);
    });

    test('registers the saved shortcut', () async {
      final saved = HotkeyBinding(
        modifiers: const {HotKeyModifier.control, HotKeyModifier.alt},
        key: LogicalKeyboardKey.keyK,
      );
      when(
        () => storage.readData(kShowHideHotkeyStorageKey),
      ).thenAnswer((_) async => saved.toJson());

      final state = controller();
      await state.start();

      expect(state.binding, saved);
      expect(registrar.registered.single.key, LogicalKeyboardKey.keyK);
    });

    test(
      'falls back to the default when the stored value is unusable',
      () async {
        when(
          () => storage.readData(kShowHideHotkeyStorageKey),
        ).thenAnswer((_) async => '{"modifiers": ["shift"], "keyId": 92}');

        final state = controller();
        await state.start();

        expect(state.binding, defaultBinding);
      },
    );

    test('still registers when the storage read throws', () async {
      when(
        () => storage.readData(kShowHideHotkeyStorageKey),
      ).thenThrow(Exception('locked'));

      final state = controller();
      await state.start();

      expect(state.binding, defaultBinding);
      expect(registrar.registered, hasLength(1));
    });

    test('reports a registration failure without throwing', () async {
      registrar.failNextRegister = true;

      final state = controller();
      await state.start();

      expect(state.isRegistered, isFalse);
      expect(state.error, isNotNull);
    });
  });

  group('update', () {
    test(
      'unregisters the old shortcut, registers and saves the new one',
      () async {
        final state = controller();
        await state.start();
        final next = HotkeyBinding(
          modifiers: const {HotKeyModifier.control, HotKeyModifier.alt},
          key: LogicalKeyboardKey.keyK,
        );

        final applied = await state.update(next);

        expect(applied, isTrue);
        expect(state.binding, next);
        expect(state.error, isNull);
        expect(registrar.unregisterCount, 1);
        expect(registrar.registered.single.key, LogicalKeyboardKey.keyK);
        verify(
          () => storage.writeData(kShowHideHotkeyStorageKey, next.toJson()),
        ).called(1);
      },
    );

    test('rejects an invalid shortcut and keeps the old one', () async {
      final state = controller();
      await state.start();

      final applied = await state.update(
        const HotkeyBinding(
          modifiers: {HotKeyModifier.shift},
          key: LogicalKeyboardKey.keyZ,
        ),
      );

      expect(applied, isFalse);
      expect(state.binding, defaultBinding);
      expect(state.error, isNotNull);
      expect(registrar.registered.single.modifiers, defaultBinding.modifiers);
      verifyNever(() => storage.writeData(any(), any()));
    });

    test('restores the previous shortcut when the new one is taken', () async {
      final state = controller();
      await state.start();
      registrar.failNextRegister = true;

      final applied = await state.update(
        HotkeyBinding(
          modifiers: const {HotKeyModifier.control},
          key: LogicalKeyboardKey.keyK,
        ),
      );

      expect(applied, isFalse);
      expect(state.binding, defaultBinding);
      expect(registrar.registered.single.modifiers, defaultBinding.modifiers);
      expect(state.error, 'That shortcut is already used by another app.');
      verifyNever(() => storage.writeData(any(), any()));
    });

    test(
      'keeps showing the previous shortcut when it cannot be restored',
      () async {
        final previous = HotkeyBinding(
          modifiers: const {HotKeyModifier.control, HotKeyModifier.alt},
          key: LogicalKeyboardKey.keyJ,
        );
        final state = controller();
        await state.start();
        await state.update(previous);
        clearInteractions(storage);
        registrar.failRegisterCount = 2;

        final applied = await state.update(
          HotkeyBinding(
            modifiers: const {HotKeyModifier.control},
            key: LogicalKeyboardKey.keyK,
          ),
        );

        expect(applied, isFalse);
        expect(state.binding, previous);
        expect(state.isRegistered, isFalse);
        expect(
          state.error,
          "That shortcut is already used by another app. Couldn't restore "
          'the previous shortcut.',
        );
        verifyNever(() => storage.writeData(any(), any()));
      },
    );

    test(
      'keeps the current shortcut in force when it cannot be released',
      () async {
        final previous = HotkeyBinding(
          modifiers: const {HotKeyModifier.control, HotKeyModifier.alt},
          key: LogicalKeyboardKey.keyJ,
        );
        final state = controller();
        await state.start();
        await state.update(previous);
        clearInteractions(storage);
        registrar.failNextUnregister = true;

        final applied = await state.update(
          HotkeyBinding(
            modifiers: const {HotKeyModifier.control},
            key: LogicalKeyboardKey.keyK,
          ),
        );

        expect(applied, isFalse);
        expect(state.binding, previous);
        expect(state.isRegistered, isTrue);
        expect(state.error, isNotNull);
        expect(registrar.registered.single.key, LogicalKeyboardKey.keyJ);
        verifyNever(() => storage.writeData(any(), any()));

        // Once the system lets go, the change goes through.
        final retried = await state.update(
          HotkeyBinding(
            modifiers: const {HotKeyModifier.control},
            key: LogicalKeyboardKey.keyK,
          ),
        );
        expect(retried, isTrue);
        expect(registrar.registered.single.key, LogicalKeyboardKey.keyK);
      },
    );

    test('reset goes back to the default shortcut', () async {
      final other = HotkeyBinding(
        modifiers: const {HotKeyModifier.control, HotKeyModifier.alt},
        key: LogicalKeyboardKey.keyK,
      );
      final state = controller();
      await state.start();
      await state.update(other);

      await state.resetToDefault();

      expect(state.binding, defaultBinding);
    });
  });

  group('toggleWindow', () {
    test('shows and focuses a hidden window', () async {
      when(() => window.isVisible()).thenAnswer((_) async => false);
      final state = controller();

      await state.toggleWindow();

      verify(() => window.show()).called(1);
      verify(() => window.focus()).called(1);
      verifyNever(() => window.hide());
    });

    test('hides the window when it already has focus', () async {
      when(() => window.isVisible()).thenAnswer((_) async => true);
      when(() => window.isFocused()).thenAnswer((_) async => true);
      final state = controller();

      await state.toggleWindow();

      verify(() => window.hide()).called(1);
      verifyNever(() => window.show());
    });

    test('brings a covered window forward instead of hiding it', () async {
      when(() => window.isVisible()).thenAnswer((_) async => true);
      when(() => window.isFocused()).thenAnswer((_) async => false);
      final state = controller();

      await state.toggleWindow();

      verify(() => window.show()).called(1);
      verify(() => window.focus()).called(1);
      verifyNever(() => window.hide());
    });

    test('restores a minimized window', () async {
      when(() => window.isMinimized()).thenAnswer((_) async => true);
      final state = controller();

      await state.toggleWindow();

      verify(() => window.restore()).called(1);
      verify(() => window.show()).called(1);
      verify(() => window.focus()).called(1);
      verifyNever(() => window.hide());
    });
  });

  test('dispose unregisters the shortcut', () async {
    final state = controller();
    await state.start();

    state.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(registrar.unregisterCount, 1);
    expect(registrar.registered, isEmpty);
  });
}
