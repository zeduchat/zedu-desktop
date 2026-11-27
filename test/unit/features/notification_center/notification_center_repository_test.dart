import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _MockApi extends Mock implements ApiBaseService {}

class _MockStorage extends Mock implements SecureStorageService {}

void main() {
  late _MockApi api;
  late _MockStorage storage;
  late NotificationCenterRepository repository;
  final stored = <String, String>{};

  setUp(() {
    api = _MockApi();
    storage = _MockStorage();
    stored.clear();
    when(() => storage.readData(any())).thenAnswer((i) async {
      return stored[i.positionalArguments.first as String];
    });
    when(() => storage.writeData(any(), any())).thenAnswer((i) async {
      stored[i.positionalArguments[0] as String] =
          i.positionalArguments[1] as String;
    });
    repository = NotificationCenterRepository(api: api, storage: storage);
  });

  group('NotificationCenterRepository (Ziki #33700)', () {
    test('loads a page of the same feed zedu-fe uses', () async {
      when(
        () => api.get<Map<String, dynamic>>(
          path: any(named: 'path'),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {
            'data': {
              'notifications': [
                {'id': 'a', 'title': 'A', 'message': 'one'},
                {'id': '', 'title': 'no id', 'message': 'dropped'},
              ],
              'pagination': {'current_page': 1, 'total_pages_count': 3},
            },
          },
        ),
      );

      final page = await repository.load('org-1', page: 1);

      verify(
        () => api.get<Map<String, dynamic>>(
          path: '/organisations/org-1/users/onesignal',
          queryParameters: {'page': 1, 'limit': 20},
        ),
      ).called(1);
      expect(page.items.map((i) => i.id), ['a']);
      expect(page.hasMore, isTrue);
    });

    test(
      'read ids and the seen time are kept per user and workspace',
      () async {
        await repository.saveReadIds('u1', 'org-1', {'a', 'b'});
        final seen = await repository.markSeenNow('u1', 'org-1');

        expect(await repository.readIds('u1', 'org-1'), {'a', 'b'});
        expect(await repository.readIds('u1', 'org-2'), isEmpty);
        expect(
          (await repository.seenAt('u1', 'org-1'))!.millisecondsSinceEpoch,
          seen.millisecondsSinceEpoch,
        );
        expect(await repository.seenAt('u2', 'org-1'), isNull);
      },
    );
  });
}
