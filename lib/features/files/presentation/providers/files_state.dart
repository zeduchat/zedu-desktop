import 'package:zedu/features/features.dart';

enum FilesTab { folders, files }

/// What the Files page is showing: the list, folder, filters, tab and page.
class FilesState {
  final FilesScope view;

  /// Folders opened from the top level, outermost first.
  final List<FileFolder> folderPath;
  final FileCategory? category;
  final DateModifiedFilter? dateModified;
  final String search;
  final FilesSort sort;
  final FilesTab tab;

  /// Page of the Files tab.
  final int page;

  /// Page of the Folders tab.
  final int folderPage;

  const FilesState({
    this.view = FilesScope.all,
    this.folderPath = const [],
    this.category,
    this.dateModified,
    this.search = '',
    this.sort = FilesSort.newestFirst,
    this.tab = FilesTab.folders,
    this.page = 1,
    this.folderPage = 1,
  });

  String? get folderId => folderPath.isEmpty ? null : folderPath.last.id;

  FilesQuery get query => FilesQuery(
    view: view,
    folderId: folderId,
    category: category,
    dateModified: dateModified,
    search: search,
    page: page,
  );
}
