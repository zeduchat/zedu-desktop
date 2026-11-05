import 'package:zedu/features/features.dart';

/// The four lists in the Files sidebar.
enum FilesScope {
  all('All files', 'all'),
  mine('My files', 'mine'),
  shared('Shared with me', 'shared'),
  trash('Deleted files', 'trash');

  const FilesScope(this.label, this.apiMode);

  final String label;

  /// Value of the `mode` query parameter.
  final String apiMode;
}

/// The web app's File Type options, in its order.
enum FileCategory {
  documents('Documents', 'documents'),
  spreadsheets('Spreadsheets', 'spreadsheets'),
  presentations('Presentations', 'presentations'),
  images('Images', 'images'),
  videos('Videos', 'videos'),
  music('Music', 'music'),
  audio('Audio', 'audio'),
  archives('Archives', 'archives'),
  code('Code', 'code');

  const FileCategory(this.label, this.apiValue);

  final String label;

  /// Value of the `file_category` query parameter.
  final String apiValue;
}

enum DateModifiedFilter {
  today('Today', 'today'),
  last7Days('Last 7 days', 'last_7_days'),
  last30Days('Last 30 days', 'last_30_days'),
  thisYear('This year', 'this_year'),
  lastYear('Last year', 'last_year');

  const DateModifiedFilter(this.label, this.apiValue);

  final String label;

  /// Value of the `date_modified` query parameter.
  final String apiValue;
}

enum FilesSort {
  newestFirst('Newest to oldest'),
  oldestFirst('Oldest to newest');

  const FilesSort(this.label);

  final String label;

  /// Sorts by date modified. Files with no date go last.
  List<WorkspaceFile> apply(List<WorkspaceFile> files) {
    final sorted = [...files];
    sorted.sort((a, b) {
      final aTime = a.modifiedAt, bTime = b.modifiedAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return this == newestFirst
          ? bTime.compareTo(aTime)
          : aTime.compareTo(bTime);
    });
    return sorted;
  }
}

/// What to ask the server for when listing files.
class FilesQuery {
  final FilesScope view;
  final String? folderId;
  final FileCategory? category;
  final DateModifiedFilter? dateModified;
  final String search;
  final int page;
  final int limit;

  const FilesQuery({
    this.view = FilesScope.all,
    this.folderId,
    this.category,
    this.dateModified,
    this.search = '',
    this.page = 1,
    this.limit = 10,
  });

  Map<String, dynamic> toQueryParameters() => {
    'mode': view.apiMode,
    'page': page,
    'limit': limit,
    if (folderId != null && folderId!.isNotEmpty) 'folder_id': folderId,
    if (category != null) 'file_category': category!.apiValue,
    if (dateModified != null) 'date_modified': dateModified!.apiValue,
    if (search.trim().isNotEmpty) 'search': search.trim(),
  };

  @override
  bool operator ==(Object other) =>
      other is FilesQuery &&
      other.view == view &&
      other.folderId == folderId &&
      other.category == category &&
      other.dateModified == dateModified &&
      other.search.trim() == search.trim() &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(
    view,
    folderId,
    category,
    dateModified,
    search.trim(),
    page,
    limit,
  );
}

/// One page of folders and how many pages there are.
class FoldersPage {
  final List<FileFolder> folders;
  final int currentPage;
  final int totalPages;

  const FoldersPage({
    required this.folders,
    this.currentPage = 1,
    this.totalPages = 1,
  });
}

/// One page of files and how many pages there are.
class FilesPage {
  final List<WorkspaceFile> files;
  final int currentPage;
  final int totalPages;

  const FilesPage({
    required this.files,
    this.currentPage = 1,
    this.totalPages = 1,
  });
}
