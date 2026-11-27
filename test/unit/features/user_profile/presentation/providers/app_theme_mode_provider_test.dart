import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  late MockSecureStorageService storage;
  late Map<String, String> saved;

  setUp(() {
    storage = MockSecureStorageService();
    saved = {};
    when(() => storage.readData(any())).thenAnswer(
      (invocation) async => saved[invocation.positionalArguments[0] as String],
    );
    when(() => storage.writeData(any(), any())).thenAnswer((invocation) async {
      saved[invocation.positionalArguments[0] as String] =
          invocation.positionalArguments[1] as String;
    });
    locator.registerSingleton<SecureStorageService>(storage);
  });

  tearDown(() async {
    await locator.reset();
  });

  Future<ThemeMode> restored() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appThemeModeProvider);
    await Future<void>.delayed(Duration.zero);
    return container.read(appThemeModeProvider);
  }

  test('follows the system when nothing is saved', () async {
    expect(await restored(), ThemeMode.system);
  });

  test('set applies and saves the mode', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(appThemeModeProvider.notifier).set(ThemeMode.dark);

    expect(container.read(appThemeModeProvider), ThemeMode.dark);
    expect(saved[AppThemeModeNotifier.storageKey], 'dark');
  });

  test('restores the saved mode on the next launch', () async {
    saved[AppThemeModeNotifier.storageKey] = 'light';

    expect(await restored(), ThemeMode.light);
  });

  test('an unknown saved value follows the system', () async {
    saved[AppThemeModeNotifier.storageKey] = 'sepia';

    expect(await restored(), ThemeMode.system);
  });

  test('a storage error keeps following the system', () async {
    when(() => storage.readData(any())).thenThrow(Exception('locked'));

    expect(await restored(), ThemeMode.system);
  });

  test('a save error still applies the mode for this session', () async {
    when(() => storage.writeData(any(), any())).thenThrow(Exception('locked'));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(appThemeModeProvider.notifier).set(ThemeMode.light);

    expect(container.read(appThemeModeProvider), ThemeMode.light);
  });
}
