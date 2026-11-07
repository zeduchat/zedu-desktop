import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class FilesNotifier extends Notifier<FilesState> {
  @override
  FilesState build() {
    // Folders belong to one workspace, so start over when it changes.
    ref.watch(currentOrgIdProvider);
    return const FilesState();
  }

  FilesState _with({
    FilesScope? view,
    List<FileFolder>? folderPath,
    FileCategory? Function()? category,
    DateModifiedFilter? Function()? dateModified,
    String? search,
    FilesSort? sort,
    FilesTab? tab,
    int? page,
    int? folderPage,
  }) => FilesState(
    view: view ?? state.view,
    folderPath: folderPath ?? state.folderPath,
    category: category != null ? category() : state.category,
    dateModified: dateModified != null ? dateModified() : state.dateModified,
    search: search ?? state.search,
    sort: sort ?? state.sort,
    tab: tab ?? state.tab,
    page: page ?? state.page,
    folderPage: folderPage ?? state.folderPage,
  );

  /// Opens one of the sidebar lists at its top level.
  void selectView(FilesScope view) {
    state = _with(view: view, folderPath: const [], page: 1, folderPage: 1);
  }

  /// Shows [view] while keeping the open folder, so uploads stay visible.
  void switchViewKeepingFolder(FilesScope view) {
    state = _with(
      view: view,
      folderPath: state.folderPath,
      page: 1,
      folderPage: 1,
    );
  }

  /// Opens [folder] inside the current one and shows its files.
  void openFolder(FileFolder folder) {
    state = _with(
      folderPath: [...state.folderPath, folder],
      tab: FilesTab.files,
      page: 1,
      folderPage: 1,
    );
  }

  /// Goes back to the folder at [depth] in the path; 0 is the top level.
  void goToDepth(int depth) {
    if (depth >= state.folderPath.length) return;
    state = _with(
      folderPath: state.folderPath.sublist(0, depth),
      page: 1,
      folderPage: 1,
    );
  }

  void setCategory(FileCategory? category) {
    state = _with(category: () => category, page: 1);
  }

  void setDateModified(DateModifiedFilter? filter) {
    state = _with(dateModified: () => filter, page: 1);
  }

  void setSearch(String search) {
    if (search.trim() == state.search.trim()) return;
    state = _with(search: search, page: 1);
  }

  /// Clears the name search, file type and date-modified filters in one
  /// refresh, keeping the folder, list, tab and sort (Ziki #3445).
  void resetFilters() {
    if (!state.hasFilters) return;
    state = _with(
      category: () => null,
      dateModified: () => null,
      search: '',
      page: 1,
    );
  }

  void setSort(FilesSort sort) {
    if (sort == state.sort) return;
    // Reversing the order moves the oldest files to the other end of the
    // list, so the page the user was on no longer means the same thing.
    state = _with(sort: sort, page: 1);
  }

  void setTab(FilesTab tab) => state = _with(tab: tab);

  void setPage(int page) {
    if (page < 1) return;
    state = _with(page: page);
  }

  void setFolderPage(int page) {
    if (page < 1) return;
    state = _with(folderPage: page);
  }
}

/// The current page of files for the Files page's query.
///
/// The server always lists files newest first and offers no sort parameter,
/// so oldest-first is read from the other end: display page 1 is the last
/// server page, display page 2 the one before it, and so on. The first page
/// is fetched once to learn how many pages there are.
class FilesListNotifier extends AsyncNotifier<FilesPage> {
  FilesQuery? _seedQuery;
  int? _serverPages;

  @override
  Future<FilesPage> build() async {
    // Equal filters in another workspace must not reuse this workspace's data.
    ref.watch(currentOrgIdProvider);
    final query = ref.watch(filesProvider.select((s) => s.query));
    final repository = ref.read(filesRepositoryProvider);

    if (query.sort == FilesSort.newestFirst) {
      _seedQuery = null;
      _serverPages = null;
      return _fetch(repository, query);
    }

    // The seed page depends on the filters, not on the page or the sort.
    final seedQuery = query.copyWith(page: 1);
    if (_seedQuery != seedQuery) {
      _seedQuery = seedQuery;
      _serverPages = null;
    }
    var totalPages = _serverPages;
    if (totalPages == null) {
      totalPages = (await _fetch(repository, seedQuery)).totalPages;
      _serverPages = totalPages;
    }

    final serverPage = (totalPages - query.page + 1).clamp(1, totalPages);
    final page = await _fetch(repository, query.copyWith(page: serverPage));
    _serverPages = page.totalPages;
    return FilesPage(
      files: query.sort.apply(page.files),
      currentPage: query.page.clamp(1, page.totalPages),
      totalPages: page.totalPages,
    );
  }

  Future<FilesPage> _fetch(FilesRepository repository, FilesQuery query) async {
    final result = await repository.fetchFiles(query);
    return switch (result) {
      Success<FilesPage>(:final value) => value,
      Failure<FilesPage>(:final error) => throw error,
    };
  }
}

/// The current page of folders in the open list and folder.
class FoldersListNotifier extends AsyncNotifier<FoldersPage> {
  @override
  Future<FoldersPage> build() async {
    ref.watch(currentOrgIdProvider);
    final (view, parentId, page) = ref.watch(
      filesProvider.select((s) => (s.view, s.folderId, s.folderPage)),
    );
    final result = await ref
        .read(filesRepositoryProvider)
        .fetchFolders(view: view, parentId: parentId, page: page);
    return switch (result) {
      Success<FoldersPage>(:final value) => value,
      Failure<FoldersPage>(:final error) => throw error,
    };
  }
}

/// What an Upload File run did.
class FilesUploadOutcome {
  final int uploaded;
  final List<String> failedNames;
  final List<String> skippedNames;
  final bool workspaceChanged;

  const FilesUploadOutcome({
    required this.uploaded,
    required this.failedNames,
    this.skippedNames = const [],
    this.workspaceChanged = false,
  });
}

/// Whether an upload or a folder creation is running.
class FilesActionsState {
  final int uploadsLeft;
  final bool isCreatingFolder;
  final bool isDeletingFolder;

  const FilesActionsState({
    this.uploadsLeft = 0,
    this.isCreatingFolder = false,
    this.isDeletingFolder = false,
  });

  bool get isUploading => uploadsLeft > 0;
}

/// Upload File and New Folder. Each refreshes the list it changed.
class FilesActionsNotifier extends Notifier<FilesActionsState> {
  int _workspaceVersion = 0;

  @override
  FilesActionsState build() {
    ref.listen(currentOrgIdProvider, (previous, next) {
      if (previous != next) _workspaceVersion++;
    });
    return const FilesActionsState();
  }

  /// Uploads [files] one at a time, as the web app does, then shows the
  /// Files tab at the top level, where the server puts uploads.
  Future<FilesUploadOutcome> uploadFiles(List<XFile> files) async {
    if (files.isEmpty || state.isUploading) {
      return const FilesUploadOutcome(uploaded: 0, failedNames: []);
    }
    final repository = ref.read(filesRepositoryProvider);
    final parentId = ref.read(filesProvider).folderId;
    final workspace = ref.read(currentOrgIdProvider);
    final version = _workspaceVersion;
    bool sameWorkspace() =>
        ref.mounted &&
        ref.read(currentOrgIdProvider) == workspace &&
        _workspaceVersion == version;
    var uploaded = 0;
    final failed = <String>[];
    final skipped = <String>[];
    state = FilesActionsState(
      uploadsLeft: files.length,
      isCreatingFolder: state.isCreatingFolder,
    );
    for (var index = 0; index < files.length; index++) {
      if (!sameWorkspace()) {
        skipped.addAll(files.skip(index).map((file) => file.name));
        break;
      }
      final file = files[index];
      final result = await repository.uploadFile(file, parentId: parentId);
      if (!ref.mounted) break;
      switch (result) {
        case Success():
          uploaded++;
        case Failure():
          failed.add(file.name);
      }
      state = FilesActionsState(
        uploadsLeft: state.uploadsLeft - 1,
        isCreatingFolder: state.isCreatingFolder,
      );
    }
    final workspaceChanged = !sameWorkspace();
    if (ref.mounted) {
      state = FilesActionsState(isCreatingFolder: state.isCreatingFolder);
    }
    if (!workspaceChanged && uploaded > 0) {
      final files = ref.read(filesProvider.notifier);
      if (ref.read(filesProvider).view == FilesScope.trash) {
        // Trash has no folders, so All files is the only place uploads can
        // show; keep the open folder so the uploaded file is visible.
        files.switchViewKeepingFolder(FilesScope.all);
      }
      files
        ..setTab(FilesTab.files)
        ..setPage(1);
      ref.invalidate(filesListProvider);
    }
    return FilesUploadOutcome(
      uploaded: uploaded,
      failedNames: failed,
      skippedNames: skipped,
      workspaceChanged: workspaceChanged,
    );
  }

  /// Creates [name] inside the open folder. Returns an error message, or
  /// null when it worked.
  Future<String?> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Enter a folder name.';
    if (state.isCreatingFolder) return null;
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) return 'Choose a workspace first.';

    state = FilesActionsState(
      uploadsLeft: state.uploadsLeft,
      isCreatingFolder: true,
    );
    final result = await ref
        .read(filesRepositoryProvider)
        .createFolder(
          name: trimmed,
          orgId: orgId,
          parentId: ref.read(filesProvider).folderId,
        );
    if (!ref.mounted) return null;
    state = FilesActionsState(uploadsLeft: state.uploadsLeft);
    switch (result) {
      case Success():
        ref.read(filesProvider.notifier).setTab(FilesTab.folders);
        ref.invalidate(foldersListProvider);
        return null;
      case Failure(:final error):
        final message = switch (error.kind) {
          ApiFailureKind.unknown || ApiFailureKind.parsing => '',
          _ => error.friendlyMessage,
        };
        return message.isNotEmpty
            ? message
            : 'Could not create the folder. Try again.';
    }
  }

  /// Deletes [folder]. Returns an error message, or null when it worked.
  Future<String?> deleteFolder(FileFolder folder) async {
    if (state.isDeletingFolder) return null;
    state = FilesActionsState(
      uploadsLeft: state.uploadsLeft,
      isCreatingFolder: state.isCreatingFolder,
      isDeletingFolder: true,
    );
    final result = await ref
        .read(filesRepositoryProvider)
        .deleteFolder(folder.id);
    if (!ref.mounted) return null;
    state = FilesActionsState(uploadsLeft: state.uploadsLeft);
    switch (result) {
      case Success():
        final notifier = ref.read(filesProvider.notifier);
        // Leaving a folder that no longer exists: step back to its parent.
        final path = ref.read(filesProvider).folderPath;
        final depth = path.indexWhere((f) => f.id == folder.id);
        if (depth >= 0) notifier.goToDepth(depth);
        notifier.setTab(FilesTab.folders);
        ref.invalidate(foldersListProvider);
        return null;
      case Failure(:final error):
        return error.message.isNotEmpty
            ? error.message
            : 'Could not delete the folder. Try again.';
    }
  }
}
