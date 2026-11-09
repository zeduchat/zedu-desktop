import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

class _MemoryStore implements TrayNoticeStore {
  bool shown = false;
  int marked = 0;

  @override
  Future<bool> hasShown() async => shown;

  @override
  Future<void> markShown() async {
    marked++;
    shown = true;
  }
}

class _FakeSecureStorage extends Fake implements SecureStorageService {
  final values = <String, String>{};
  bool readFails = false;
  bool writeFails = false;

  @override
  Future<String?> readData(String key) async {
    if (readFails) throw StateError('keyring locked');
    return values[key];
  }

  @override
  Future<void> writeData(String key, String value) async {
    if (writeFails) throw StateError('keyring locked');
    values[key] = value;
  }
}

void _register(SecureStorageService storage) {
  if (locator.isRegistered<SecureStorageService>()) {
    locator.unregister<SecureStorageService>();
  }
  locator.registerSingleton<SecureStorageService>(storage);
}

void main() {
  group('the text', () {
    test('has the same title everywhere', () {
      expect(trayCloseNoticeTitle, 'Zedu is still running');
    });

    test('Windows and Linux say tray icon', () {
      expect(
        trayCloseNoticeBody(TargetPlatform.windows),
        'Open or quit it from the tray icon.',
      );
      expect(
        trayCloseNoticeBody(TargetPlatform.linux),
        'Open or quit it from the tray icon.',
      );
    });

    test('macOS says the menu bar, where its icon is', () {
      expect(
        trayCloseNoticeBody(TargetPlatform.macOS),
        'Open or quit it from the Zedu icon in the menu bar.',
      );
    });
  });

  group('shouldShowTrayCloseNotice', () {
    test('only the first time and only with a tray icon', () {
      expect(
        shouldShowTrayCloseNotice(trayIconShown: true, alreadyShown: false),
        isTrue,
      );
      expect(
        shouldShowTrayCloseNotice(trayIconShown: true, alreadyShown: true),
        isFalse,
      );
      expect(
        shouldShowTrayCloseNotice(trayIconShown: false, alreadyShown: false),
        isFalse,
      );
      expect(
        shouldShowTrayCloseNotice(trayIconShown: false, alreadyShown: true),
        isFalse,
      );
    });
  });

  group('TrayCloseNotice.showIfFirstClose', () {
    late _MemoryStore store;
    late List<(String, String)> shown;

    TrayCloseNotice notice({Future<void> Function(String, String)? show}) =>
        TrayCloseNotice(
          store: store,
          show:
              show ??
              (title, body) async {
                shown.add((title, body));
              },
        );

    setUp(() {
      store = _MemoryStore();
      shown = [];
    });

    test('shows it the first time, with the platform text', () async {
      final didShow = await notice().showIfFirstClose(
        trayIconShown: true,
        platform: TargetPlatform.macOS,
      );

      expect(didShow, isTrue);
      expect(shown, [
        (
          'Zedu is still running',
          'Open or quit it from the Zedu icon in the menu bar.',
        ),
      ]);
    });

    test('does not show it a second time', () async {
      final n = notice();
      await n.showIfFirstClose(
        trayIconShown: true,
        platform: TargetPlatform.windows,
      );

      final again = await n.showIfFirstClose(
        trayIconShown: true,
        platform: TargetPlatform.windows,
      );

      expect(again, isFalse);
      expect(shown, hasLength(1));
    });

    test('remembers it was shown, even for a new notice object', () async {
      await notice().showIfFirstClose(
        trayIconShown: true,
        platform: TargetPlatform.linux,
      );

      final later = await notice().showIfFirstClose(
        trayIconShown: true,
        platform: TargetPlatform.linux,
      );

      expect(store.marked, 1);
      expect(store.shown, isTrue);
      expect(later, isFalse);
      expect(shown, hasLength(1));
    });

    test('says nothing without a tray icon, and keeps it for later', () async {
      final didShow = await notice().showIfFirstClose(
        trayIconShown: false,
        platform: TargetPlatform.linux,
      );

      expect(didShow, isFalse);
      expect(shown, isEmpty);
      expect(store.shown, isFalse);

      final later = await notice().showIfFirstClose(
        trayIconShown: true,
        platform: TargetPlatform.linux,
      );
      expect(later, isTrue);
    });

    test('a failing notification does not throw and is not retried', () async {
      final failing = notice(show: (_, _) async => throw StateError('no'));

      final first = await failing.showIfFirstClose(
        trayIconShown: true,
        platform: TargetPlatform.windows,
      );
      final second = await notice().showIfFirstClose(
        trayIconShown: true,
        platform: TargetPlatform.windows,
      );

      expect(first, isFalse);
      expect(second, isFalse);
      expect(shown, isEmpty);
    });
  });

  group('SecureTrayNoticeStore', () {
    late _FakeSecureStorage storage;

    setUp(() {
      storage = _FakeSecureStorage();
      _register(storage);
    });

    test('is not shown on a fresh install, then is once marked', () async {
      final store = SecureTrayNoticeStore();
      expect(await store.hasShown(), isFalse);

      await store.markShown();

      expect(storage.values[SecureTrayNoticeStore.storageKey], 'true');
      expect(await SecureTrayNoticeStore().hasShown(), isTrue);
    });

    test('an unreadable store counts as shown, so it stays quiet', () async {
      storage.readFails = true;

      expect(await SecureTrayNoticeStore().hasShown(), isTrue);
    });

    test(
      'a store that cannot be written still shows it once per run',
      () async {
        storage.writeFails = true;
        final store = SecureTrayNoticeStore();
        final n = TrayCloseNotice(store: store, show: (_, _) async {});

        final first = await n.showIfFirstClose(
          trayIconShown: true,
          platform: TargetPlatform.windows,
        );
        final second = await n.showIfFirstClose(
          trayIconShown: true,
          platform: TargetPlatform.windows,
        );

        expect(first, isTrue);
        expect(second, isFalse);
      },
    );
  });
}
