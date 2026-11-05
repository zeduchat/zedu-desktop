import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/channels/data/datasources/channel_draft_store.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  group('ChannelDraftStore', () {
    late MockSecureStorageService storage;
    late Map<String, String> values;

    setUp(() {
      storage = MockSecureStorageService();
      values = <String, String>{};

      when(() => storage.readData(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments[0] as String;
        return values[key];
      });

      when(() => storage.writeData(any(), any())).thenAnswer((
        invocation,
      ) async {
        final key = invocation.positionalArguments[0] as String;
        final value = invocation.positionalArguments[1] as String;
        values[key] = value;
      });

      when(() => storage.deleteValue(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments[0] as String;
        values.remove(key);
      });
    });

    test('saves and retrieves a draft', () async {
      final store = ChannelDraftStore(
        storage,
        userId: 'user-1',
        orgId: 'org-1',
      );

      await store.saveDraft('channel-1', 'hello team');
      final draft = await store.getDraft('channel-1');

      expect(draft, 'hello team');
      expect(values['channel_draft_user-1_org-1_channel-1'], 'hello team');
    });

    test('keeps drafts separate per channel', () async {
      final store = ChannelDraftStore(
        storage,
        userId: 'user-1',
        orgId: 'org-1',
      );

      await store.saveDraft('channel-1', 'first');
      await store.saveDraft('channel-2', 'second');

      expect(await store.getDraft('channel-1'), 'first');
      expect(await store.getDraft('channel-2'), 'second');
    });

    test('scopes drafts to the user and org', () async {
      final first = ChannelDraftStore(
        storage,
        userId: 'user-1',
        orgId: 'org-1',
      );
      final second = ChannelDraftStore(
        storage,
        userId: 'user-2',
        orgId: 'org-1',
      );

      await first.saveDraft('channel-1', 'private');

      expect(await second.getDraft('channel-1'), isNull);
      expect(await first.getDraft('channel-1'), 'private');
    });

    test('clears a draft', () async {
      final store = ChannelDraftStore(
        storage,
        userId: 'user-1',
        orgId: 'org-1',
      );

      await store.saveDraft('channel-1', 'temporary');
      await store.clearDraft('channel-1');

      expect(await store.getDraft('channel-1'), isNull);
      expect(values.containsKey('channel_draft_user-1_org-1_channel-1'), false);
    });

    test('empty and whitespace-only text clears the draft', () async {
      final store = ChannelDraftStore(
        storage,
        userId: 'user-1',
        orgId: 'org-1',
      );

      await store.saveDraft('channel-1', 'temporary');
      await store.saveDraft('channel-1', '   ');

      expect(await store.getDraft('channel-1'), isNull);
    });

    test('returns null when there is no draft', () async {
      final store = ChannelDraftStore(
        storage,
        userId: 'user-1',
        orgId: 'org-1',
      );

      expect(await store.getDraft('missing'), isNull);
    });
  });
}
