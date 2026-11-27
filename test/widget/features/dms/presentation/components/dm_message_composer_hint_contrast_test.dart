import 'dart:math';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _MemoryStorage extends Fake implements SecureStorageService {
  final _values = <String, String>{};

  @override
  Future<String?> readData(String key) async => _values[key];

  @override
  Future<void> writeData(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> deleteValue(String key) async => _values.remove(key);
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  testWidgets('the placeholder meets AA contrast in dark mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dmDraftStoreProvider.overrideWith(
            (ref) => DmDraftStore(
              _MemoryStorage(),
              userId: 'user-1',
              orgId: 'org-1',
            ),
          ),
        ],
        child: buildTestMaterialApp(
          Theme(
            data: AppTheme.dark,
            child: const Scaffold(
              body: DmMessageComposer(recipientName: 'Ada', channelId: 'dm-1'),
            ),
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final hint = field.decoration!.hintStyle!.color!;

    expect(hint, AppPalette.dark.textHint);
    expect(
      _contrast(hint, AppPalette.dark.background),
      greaterThanOrEqualTo(4.5),
    );
  });
}
