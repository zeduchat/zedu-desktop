import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class _DelayedReadStorage extends Fake implements SecureStorageService {
  final Completer<String?> readCompleter = Completer<String?>();

  @override
  Future<String?> readData(String key) => readCompleter.future;

  @override
  Future<void> writeData(String key, String value) async {}
}

void main() {
  test(
    'a late initial read does not replace a draft saved while it waits',
    () async {
      final storage = _DelayedReadStorage();
      final store = DmDraftStore(storage, userId: 'user-1', orgId: 'org-1');

      final pendingLoad = store.load('channel-1');
      await store.save('channel-1', 'new draft', updatedAt: 42);
      storage.readCompleter.complete(null);

      await pendingLoad;

      expect(store.peek('channel-1')?.text, 'new draft');
      expect(store.peek('channel-1')?.updatedAt, 42);
      store.dispose();
    },
  );

  test(
    'a late initial read does not restore a draft cleared while it waits',
    () async {
      final storage = _DelayedReadStorage();
      final store = DmDraftStore(storage, userId: 'user-1', orgId: 'org-1');

      final pendingLoad = store.load('channel-1');
      await store.clear('channel-1');
      storage.readCompleter.complete('{"text":"old draft","updatedAt":7}');

      await pendingLoad;

      expect(store.peek('channel-1'), isNull);
      store.dispose();
    },
  );
}
