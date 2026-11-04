import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Owns the temp-file lifecycle for voice notes.
///
/// `presentation/` must not know about the filesystem (the feature is layered
/// `data/` -> `domain/` -> `presentation/`), so the composer and the chat
/// history provider ask this store to build a recording path and to delete the
/// files the app itself recorded. Files the user picked are never tracked, and
/// so are never deleted.
class VoiceNoteStore {
  /// A fresh path for a recording in the platform's temp directory.
  String newRecordingPath({DateTime? now}) {
    final stamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return '${Directory.systemTemp.path}'
        '${Platform.pathSeparator}zedu-voice-$stamp.m4a';
  }

  /// Records [path] as a file this app created, so it may be deleted later.
  void track(String path) => appRecordedPaths.add(path);

  /// Deletes [path] only when this app recorded it.
  ///
  /// Returns `true` when a file was removed. A failure is logged instead of
  /// thrown, because every caller is a cleanup path that must not change the
  /// flow of a UI action.
  Future<bool> delete(String? path) async {
    if (path == null || !appRecordedPaths.remove(path)) return false;
    try {
      await File(path).delete();
      return true;
    } on FileSystemException catch (error, stackTrace) {
      AppLogger.w(
        'Could not delete voice note: $path',
        tag: 'VoiceNoteStore',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Deletes each of [paths] that this app recorded.
  Future<void> deleteAll(Iterable<String?> paths) async {
    for (final path in paths) {
      await delete(path);
    }
  }
}

final voiceNoteStoreProvider = Provider<VoiceNoteStore>(
  (ref) => VoiceNoteStore(),
);
