import 'dart:io';

import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  late Directory tempDir;
  late VoiceNoteStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zedu_voice_note_store');
    appRecordedPaths.clear();
    store = VoiceNoteStore();
  });

  tearDown(() async {
    appRecordedPaths.clear();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  File writeFile(String name) {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    file.writeAsStringSync('audio');
    return file;
  }

  group('VoiceNoteStore.newRecordingPath', () {
    test('builds a unique m4a path inside the temp directory', () {
      final first = store.newRecordingPath(now: DateTime.utc(2026, 1, 1));
      final second = store.newRecordingPath(now: DateTime.utc(2026, 1, 2));

      expect(first, endsWith('.m4a'));
      expect(first, contains(Directory.systemTemp.path));
      expect(first, isNot(second));
    });
  });

  group('VoiceNoteStore.delete', () {
    test('deletes a file this app recorded', () async {
      final file = writeFile('recorded.m4a');
      store.track(file.path);

      expect(await store.delete(file.path), isTrue);
      expect(file.existsSync(), isFalse);
    });

    test('leaves a file the app did not record, even when it exists', () async {
      final file = writeFile('picked-by-the-user.m4a');

      expect(await store.delete(file.path), isFalse);
      expect(file.existsSync(), isTrue);
    });

    test('returns false for a null path', () async {
      expect(await store.delete(null), isFalse);
    });

    test('does not throw when a tracked file is already gone', () async {
      final file = writeFile('gone.m4a');
      store.track(file.path);
      await file.delete();

      expect(await store.delete(file.path), isFalse);
    });
  });

  group('VoiceNoteStore.deleteAll', () {
    test('deletes only the recordings this app made', () async {
      final recorded = writeFile('recorded.m4a');
      final picked = writeFile('picked-by-the-user.m4a');
      store.track(recorded.path);

      await store.deleteAll([recorded.path, picked.path, null]);

      expect(recorded.existsSync(), isFalse);
      expect(picked.existsSync(), isTrue);
    });
  });
}
