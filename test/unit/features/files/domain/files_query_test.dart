import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

void main() {
  test('a plain query asks for the first page of all files', () {
    expect(const FilesQuery().toQueryParameters(), {
      'mode': 'all',
      'page': 1,
      'limit': 10,
    });
  });

  test('queries that differ only in search spacing are equal', () {
    expect(
      const FilesQuery(search: 'logo'),
      const FilesQuery(search: ' logo '),
    );
    expect(const FilesQuery(page: 1) == const FilesQuery(page: 2), isFalse);
  });

  test('sort orders by date modified with undated files last', () {
    final files = [
      WorkspaceFile(id: 'old', name: 'old', updatedAt: DateTime(2026, 1, 1)),
      const WorkspaceFile(id: 'none', name: 'none'),
      WorkspaceFile(id: 'new', name: 'new', createdAt: DateTime(2026, 6, 1)),
    ];

    expect(FilesSort.newestFirst.apply(files).map((f) => f.id), [
      'new',
      'old',
      'none',
    ]);
    expect(FilesSort.oldestFirst.apply(files).map((f) => f.id), [
      'old',
      'new',
      'none',
    ]);
  });

  test('a file takes its type from a MIME type or its name', () {
    expect(
      WorkspaceFile.fromJson({
        'file_name': 'a',
        'file_type': 'image/JPEG',
      }).fileType,
      'jpeg',
    );
    final doc = WorkspaceFile.fromJson({'file_name': 'Report.DOCX'});
    expect(doc.fileType, 'docx');
    expect(doc.isImage, isFalse);
    expect(WorkspaceFile.fromJson(const {}).name, 'Untitled file');
  });

  test('formats sizes, dates and item counts', () {
    expect(formatFileSize(512), '512 B');
    expect(formatFileSize(1536), '1.5 KB');
    expect(formatFileSize(12 * 1024 * 1024), '12 MB');
    expect(formatFileDate(DateTime(2026, 11, 1)), 'Nov 1, 2026');
    expect(formatFileDate(null), '—');
    expect(formatItemCount(1), '1 item');
    expect(formatItemCount(0), '0 items');
  });
}
