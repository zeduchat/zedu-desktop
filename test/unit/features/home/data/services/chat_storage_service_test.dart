import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/home/data/services/chat_storage_service.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  group('ChatStorageService', () {
    late MockSecureStorageService mockStorage;
    late Map<String, String> inMemoryStore;

    setUp(() {
      mockStorage = MockSecureStorageService();
      inMemoryStore = <String, String>{};

      when(() => mockStorage.readData(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments[0] as String;
        return inMemoryStore[key];
      });

      when(() => mockStorage.writeData(any(), any())).thenAnswer((
        invocation,
      ) async {
        final key = invocation.positionalArguments[0] as String;
        final value = invocation.positionalArguments[1] as String;
        inMemoryStore[key] = value;
      });

      when(() => mockStorage.deleteValue(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments[0] as String;
        inMemoryStore.remove(key);
      });
    });

    group('buildKey', () {
      test('scopes key with userId and orgId when present', () {
        final service = ChatStorageService(
          mockStorage,
          userId: 'user-123',
          orgId: 'org-456',
        );

        expect(
          service.buildKey('group-789'),
          'chat_messages_user-123_org-456_group-789',
        );
      });

      test('falls back to unscoped key when userId or orgId is missing', () {
        final serviceWithoutOrg = ChatStorageService(
          mockStorage,
          userId: 'user-123',
        );
        expect(
          serviceWithoutOrg.buildKey('group-789'),
          'chat_messages_group-789',
        );

        final serviceEmpty = ChatStorageService(mockStorage);
        expect(serviceEmpty.buildKey('group-789'), 'chat_messages_group-789');
      });

      test('allows method-level override of userId and orgId', () {
        final service = ChatStorageService(
          mockStorage,
          userId: 'user-default',
          orgId: 'org-default',
        );

        expect(
          service.buildKey(
            'group-789',
            userId: 'user-custom',
            orgId: 'org-custom',
          ),
          'chat_messages_user-custom_org-custom_group-789',
        );
      });
    });

    group('getCachedMessages error resilience', () {
      test('returns empty list when storage data is null', () async {
        final service = ChatStorageService(mockStorage);
        final messages = await service.getCachedMessages('group-1');

        expect(messages, isEmpty);
      });

      test('returns empty list when storage data is malformed JSON', () async {
        final service = ChatStorageService(mockStorage);
        inMemoryStore['chat_messages_group-1'] = '{ invalid json content }';

        final messages = await service.getCachedMessages('group-1');
        expect(messages, isEmpty);
      });

      test(
        'returns empty list when storage data is a JSON object instead of a list',
        () async {
          final service = ChatStorageService(mockStorage);
          inMemoryStore['chat_messages_group-1'] = '{"message": "hello"}';

          final messages = await service.getCachedMessages('group-1');
          expect(messages, isEmpty);
        },
      );

      test(
        'returns empty list when storage data is a primitive JSON value',
        () async {
          final service = ChatStorageService(mockStorage);
          inMemoryStore['chat_messages_group-1'] = '12345';

          final messages = await service.getCachedMessages('group-1');
          expect(messages, isEmpty);
        },
      );

      test('correctly decodes valid JSON list of messages', () async {
        final service = ChatStorageService(mockStorage);
        inMemoryStore['chat_messages_group-1'] = '["Hello", "World", 42]';

        final messages = await service.getCachedMessages('group-1');
        expect(messages, ['Hello', 'World', '42']);
      });
    });

    group('account and organization storage isolation', () {
      test(
        'isolates messages between different users and organizations',
        () async {
          final userAService = ChatStorageService(
            mockStorage,
            userId: 'user-A',
            orgId: 'org-1',
          );
          final userBService = ChatStorageService(
            mockStorage,
            userId: 'user-B',
            orgId: 'org-1',
          );
          final userAOtherOrgService = ChatStorageService(
            mockStorage,
            userId: 'user-A',
            orgId: 'org-2',
          );

          await userAService.saveMessages('group-1', ['User A secret message']);

          expect(await userAService.getCachedMessages('group-1'), [
            'User A secret message',
          ]);
          expect(await userBService.getCachedMessages('group-1'), isEmpty);
          expect(
            await userAOtherOrgService.getCachedMessages('group-1'),
            isEmpty,
          );
        },
      );

      test('appendMessage correctly appends to isolated user cache', () async {
        final service = ChatStorageService(
          mockStorage,
          userId: 'user-1',
          orgId: 'org-1',
        );

        await service.saveMessages('group-1', ['Initial message']);
        await service.appendMessage('group-1', 'Appended message');

        final cached = await service.getCachedMessages('group-1');
        expect(cached, ['Initial message', 'Appended message']);
      });

      test(
        'clearCachedMessages removes only the targeted user/org cache',
        () async {
          final service = ChatStorageService(
            mockStorage,
            userId: 'user-1',
            orgId: 'org-1',
          );
          final otherService = ChatStorageService(
            mockStorage,
            userId: 'user-2',
            orgId: 'org-1',
          );

          await service.saveMessages('group-1', ['Msg 1']);
          await otherService.saveMessages('group-1', ['Msg 2']);

          await service.clearCachedMessages('group-1');

          expect(await service.getCachedMessages('group-1'), isEmpty);
          expect(await otherService.getCachedMessages('group-1'), ['Msg 2']);
        },
      );
    });
  });
}
