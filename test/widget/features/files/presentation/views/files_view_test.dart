import 'dart:async';
import 'dart:convert';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Workspace A', avatar: ''),
  );
}

/// Signed in as Ada (u-1), who uploaded logo.png.
class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'u-1',
      firstName: 'Ada',
      lastName: 'Lovelace',
      email: 'ada@zedu.test',
      phone: '',
      username: 'ada',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026, 1, 1),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'org-1',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

class _FakeProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState(
    teamMembers: [
      TeamMember(
        id: 'u-1',
        email: 'ada@zedu.test',
        role: 'Admin',
        dateJoined: '2026-01-01',
        status: TeamMemberStatus.active,
        name: 'Ada Lovelace',
      ),
    ],
  );

  @override
  Future<void> load() async {}
}
class _FakePeopleRepository implements PeopleRepository {
  static const members = [
    OrgMember(id: 'u-2', name: 'Grace Hopper', email: 'grace@zedu.test'),
    OrgMember(id: 'u-3', name: 'Alan Turing', email: 'alan@zedu.test'),
  ];

  @override
  Future<Result<MembersPage>> fetchMembers({
    required String orgId,
    int page = 1,
    String search = '',
  }) async {
    final query = search.toLowerCase();
    final found = [
      for (final m in members)
        if (m.name.toLowerCase().contains(query)) m,
    ];
    return Success(
      MembersPage(
        members: found,
        currentPage: 1,
        totalPages: 1,
        totalItems: found.length,
      ),
    );
  }
}

class _FakeFilesRepository implements FilesRepository {
  _FakeFilesRepository({
    this.failFolders = false,
    this.failCreate = false,
    this.createFailure,
  });

  final bool failFolders;
  final bool failCreate;
  final ApiFailure? createFailure;
  final queries = <FilesQuery>[];
  final folderRequests = <(FilesScope, String?)>[];
  final createdFolders = <(String, String, String?)>[];
  final downloads = <(String, String)>[];
  final deletes = <(String, bool)>[];
  final renames = <(String, String)>[];
  final moves = <(String, String)>[];
  Result<void> moveResult = const Success(null);

  /// The folders inside each folder, by that folder's id.
  final subfolders = <String, List<FileFolder>>{};

  /// Folders whose subfolders fail to load.
  final failingFolderLevels = <String>{};

  @override
  Future<Result<void>> moveFile(String fileId, String folderId) async {
    moves.add((fileId, folderId));
    return moveResult;
  }

  final shares =
      <(String, List<String>, FileSharePermission, FileShareAccess, String)>[];
  Result<FileShareResult> shareResult = const Success(
    FileShareResult(sentTo: ['u-2']),
  );

  @override
  Future<Result<FileShareResult>> shareFile({
    required String fileId,
    required List<String> recipientIds,
    required FileSharePermission permission,
    required FileShareAccess access,
    String note = '',
  }) async {
    shares.add((fileId, recipientIds, permission, access, note));
    return shareResult;
  }

  final previews = <(String, FilePreviewKind)>[];
  Result<Uint8List> Function(WorkspaceFile file) preview = (_) =>
      Success(Uint8List.fromList(utf8.encode('hello from the file')));

  @override
  Future<Result<Uint8List>> fetchFilePreview(
    WorkspaceFile file,
    FilePreviewKind kind,
  ) async {
    previews.add((file.id, kind));
    return preview(file);
  }

  /// What `GET /files/file/{id}` returns; completes at once by default.
  Completer<Result<WorkspaceFile>> details = Completer()
    ..complete(
      Success(
        WorkspaceFile(
          id: 'f-1',
          name: 'logo.png',
          fileType: 'png',
          size: 2048,
          userId: 'u-1',
          sharedIn: 'general',
          createdAt: DateTime(2026, 10, 30, 14, 5),
          updatedAt: DateTime(2026, 11, 1, 9, 30),
          accessType: 'private',
        ),
      ),
    );
  final detailRequests = <String>[];

  @override
  Future<Result<WorkspaceFile>> fetchFileDetails(String fileId) {
    detailRequests.add(fileId);
    return details.future;
  }

  Set<String> pinnedIds = {};
  final pinCalls = <(String, bool)>[];
  Result<void> pinResult = const Success(null);

  @override
  Future<Result<Set<String>>> fetchPinnedFileIds() async =>
      Success({...pinnedIds});

  @override
  Future<Result<void>> pinFile(String fileId) async {
    pinCalls.add((fileId, true));
    return pinResult;
  }

  @override
  Future<Result<void>> unpinFile(String fileId) async {
    pinCalls.add((fileId, false));
    return pinResult;
  }

  Result<void> renameResult = const Success(null);

  @override
  Future<Result<void>> renameFile(String fileId, String name) async {
    renames.add((fileId, name));
    return renameResult;
  }

  Result<void> deleteResult = const Success(null);

  @override
  Future<Result<void>> deleteFile(
    String fileId, {
    bool permanent = false,
  }) async {
    deletes.add((fileId, permanent));
    return deleteResult;
  }

  /// What a download returns; complete it to finish the download.
  Completer<Result<void>> download = Completer()..complete(const Success(null));
  void Function(double?)? reportProgress;

  @override
  Future<Result<void>> downloadFile({
    required WorkspaceFile file,
    required String savePath,
    void Function(double? progress)? onProgress,
  }) {
    downloads.add((file.id, savePath));
    reportProgress = onProgress;
    return download.future;
  }

  @override
  Future<Result<FilesPage>> fetchFiles(FilesQuery query) async {
    queries.add(query);
    if (query.folderId == 'docs') {
      return const Success(
        FilesPage(
          files: [WorkspaceFile(id: 'f-2', name: 'spec.pdf', folderId: 'docs')],
        ),
      );
    }
    return Success(
      FilesPage(
        files: [
          WorkspaceFile(
            id: 'f-1',
            name: 'logo.png',
            fileType: 'png',
            size: 2048,
            userId: 'u-1',
            sharedIn: 'general',
            updatedAt: DateTime(2026, 11, 1),
          ),
          ...moreFiles,
        ],
      ),
    );
  }

  /// Files listed after logo.png on the main list.
  List<WorkspaceFile> moreFiles = [];

  @override
  Future<Result<FoldersPage>> fetchFolders({
    required FilesScope view,
    String? parentId,
    int page = 1,
  }) async {
    folderRequests.add((view, parentId));
    if (failFolders) {
      return const Failure(ApiFailure(message: 'offline'));
    }
    if (parentId != null) {
      if (failingFolderLevels.contains(parentId)) {
        return const Failure(ApiFailure(message: 'offline'));
      }
      return Success(FoldersPage(folders: subfolders[parentId] ?? const []));
    }
    return Success(
      FoldersPage(
        folders: [
          FileFolder(
            id: 'docs',
            name: 'docs',
            userId: 'u-1',
            itemCount: 1,
            createdAt: DateTime(2026, 11, 1),
          ),
          for (final (name, _, _) in createdFolders)
            FileFolder(id: name, name: name),
        ],
      ),
    );
  }

  @override
  Future<Result<WorkspaceFile>> uploadFile(
    XFile file, {
    String? parentId,
  }) async => Success(WorkspaceFile(id: 'up', name: file.name));

  @override
  Future<Result<void>> createFolder({
    required String name,
    required String orgId,
    String? parentId,
  }) async {
    if (failCreate) {
      return const Failure(
        ApiFailure(
          message: 'Folder name already exists',
          kind: ApiFailureKind.client,
        ),
      );
    }
    if (createFailure case final error?) return Failure(error);
    createdFolders.add((name, orgId, parentId));
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteFolder(String id) async {
    deletes.add((id, true));
    return const Success(null);
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeFilesRepository repository, {
  String? savePath = '/Users/ada/Downloads/logo.png',
}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        userProfileNotifierProvider.overrideWith(_FakeProfileNotifier.new),
        filesRepositoryProvider.overrideWithValue(repository),
        peopleRepositoryProvider.overrideWithValue(_FakePeopleRepository()),
        saveLocationPickerProvider.overrideWithValue((_) async => savePath),
      ],
      child: buildTestMaterialApp(
        const Scaffold(
          body: Row(
            children: [
              FilesSidebar(),
              Expanded(child: FilesView()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on All files with the folders listed', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);

    for (final label in [
      'All files',
      'My files',
      'Shared with me',
      'Deleted files',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Channels'), findsNothing);
    expect(find.text('docs'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Nov 1, 2026'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
    expect(repository.folderRequests.last, (FilesScope.all, null));
  });

  testWidgets('labels the folder item count column Items', (tester) async {
    await _pump(tester, _FakeFilesRepository());

    expect(find.text('Items'), findsOneWidget);
    expect(find.text('Size'), findsNothing);
  });

  testWidgets('the Files tab lists files with their details', (tester) async {
    await _pump(tester, _FakeFilesRepository());

    await tester.tap(find.text('Files').last);
    await tester.pumpAndSettle();

    expect(find.text('logo.png'), findsOneWidget);
    expect(find.text('general'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('2 KB'), findsOneWidget);
  });

  testWidgets('a sidebar list loads that list', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);

    await tester.tap(find.text('Deleted files'));
    await tester.pumpAndSettle();

    expect(repository.folderRequests.last, (FilesScope.trash, null));
    // The title follows the list.
    expect(find.text('Deleted files'), findsNWidgets(2));
  });

  testWidgets('opening a folder shows its files and a way back', (
    tester,
  ) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);

    await tester.tap(find.text('docs'));
    await tester.pumpAndSettle();

    expect(repository.queries.last.folderId, 'docs');
    expect(find.text('spec.pdf'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'All files'));
    await tester.pumpAndSettle();

    expect(repository.queries.last.folderId, isNull);
  });

  testWidgets('choosing a file type filters on the server', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);

    await tester.tap(find.text('File Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Images').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Files').last);
    await tester.pumpAndSettle();

    expect(repository.queries.last.category, FileCategory.images);
  });

  testWidgets('shows a retry when folders fail to load', (tester) async {
    await _pump(tester, _FakeFilesRepository(failFolders: true));

    expect(find.text('Could not load folders'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Upload File and New Folder are hidden in Deleted files', (
    tester,
  ) async {
    await _pump(tester, _FakeFilesRepository());

    expect(find.text('Upload File'), findsOneWidget);
    expect(find.text('New Folder'), findsOneWidget);

    await tester.tap(find.text('Deleted files'));
    await tester.pumpAndSettle();

    expect(find.text('Upload File'), findsNothing);
    expect(find.text('New Folder'), findsNothing);
  });

  testWidgets('New Folder creates the folder and lists it', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);

    await tester.tap(find.text('New Folder'));
    await tester.pumpAndSettle();
    expect(find.text('Create New Folder'), findsOneWidget);

    // An empty name is refused without calling the server.
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a folder name.'), findsOneWidget);
    expect(repository.createdFolders, isEmpty);

    await tester.enterText(find.byType(TextField).last, '  Reports  ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(repository.createdFolders, [('Reports', 'org-1', null)]);
    expect(find.text('Create New Folder'), findsNothing);
    expect(find.text('Folder created'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('inside a folder there is no Folders tab or New Folder', (
    tester,
  ) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);

    await tester.tap(find.text('docs'));
    await tester.pumpAndSettle();

    expect(find.text('spec.pdf'), findsOneWidget);
    expect(find.text('Folders'), findsNothing);
    expect(find.text('New Folder'), findsNothing);
    expect(find.text('Upload File'), findsOneWidget);

    // Back at the top level, both come back.
    await tester.tap(find.widgetWithText(TextButton, 'All files'));
    await tester.pumpAndSettle();

    expect(find.text('Folders'), findsWidgets);
    expect(find.text('New Folder'), findsOneWidget);
  });

  testWidgets('New Folder shows the server error and stays open', (
    tester,
  ) async {
    await _pump(tester, _FakeFilesRepository(failCreate: true));

    await tester.tap(find.text('New Folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'docs');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Folder name already exists'), findsOneWidget);
    expect(find.text('Create New Folder'), findsOneWidget);
  });

  for (final (kind, expected) in [
    (
      ApiFailureKind.network,
      'No internet connection. Check your network and try again.',
    ),
    (
      ApiFailureKind.server,
      'Something went wrong on our end. Please try again later.',
    ),
  ]) {
    testWidgets('New Folder $kind shows safe copy and keeps the entered name', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeFilesRepository(
          createFailure: ApiFailure(
            message: '<html>internal-host failure</html>',
            kind: kind,
          ),
        ),
      );
      await tester.tap(find.text('New Folder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Reports');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
      expect(find.textContaining('internal-host'), findsNothing);
      expect(find.text('Create New Folder'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'Reports',
      );
    });
  }

  Future<void> openFilesTab(WidgetTester tester) async {
    await tester.tap(find.text('Files').last);
    await tester.pumpAndSettle();
  }

  Finder actionsMenu() => find.byTooltip('More actions for logo.png');

  Future<void> chooseDownload(WidgetTester tester) async {
    await tester.tap(actionsMenu());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download'));
  }

  testWidgets('downloads a file to the chosen folder', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseDownload(tester);
    await tester.pumpAndSettle();

    expect(repository.downloads, [('f-1', '/Users/ada/Downloads/logo.png')]);
    expect(find.text('Downloaded logo.png to Downloads.'), findsOneWidget);
    // Lets the toast time out.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('shows progress while a file downloads', (tester) async {
    final repository = _FakeFilesRepository()..download = Completer();
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseDownload(tester);
    await tester.pump();
    repository.reportProgress!(0.5);
    await tester.pump();

    expect(actionsMenu(), findsNothing);
    expect(find.byTooltip('Downloading 50%'), findsOneWidget);

    repository.download.complete(const Success(null));
    await tester.pumpAndSettle();
    expect(actionsMenu(), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('says when a download fails', (tester) async {
    final repository = _FakeFilesRepository()
      ..download = (Completer()
        ..complete(
          const Failure(
            ApiFailure(message: 'offline', kind: ApiFailureKind.network),
          ),
        ));
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseDownload(tester);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not download logo.png. '
        'No internet connection. Check your network and try again.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('cancelling the save dialog downloads nothing', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository, savePath: null);
    await openFilesTab(tester);

    await chooseDownload(tester);
    await tester.pumpAndSettle();

    expect(repository.downloads, isEmpty);
  });

  Future<void> chooseInMenu(WidgetTester tester, String label) async {
    await tester.tap(actionsMenu());
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('deletes a file after confirming', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);
    await openFilesTab(tester);
    final loads = repository.queries.length;

    await chooseInMenu(tester, 'Delete');
    expect(find.text('Delete file?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletes, [('f-1', false)]);
    expect(find.text('Delete file?'), findsNothing);
    expect(find.text('Moved logo.png to Deleted files.'), findsOneWidget);
    // The list reloads, so the file leaves it.
    expect(repository.queries.length, loads + 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed delete keeps the dialog open with the reason', (
    tester,
  ) async {
    final repository = _FakeFilesRepository()
      ..deleteResult = const Failure(
        ApiFailure(message: 'nope', kind: ApiFailureKind.forbidden),
      );
    await _pump(tester, repository);
    await openFilesTab(tester);
    final loads = repository.queries.length;

    await chooseInMenu(tester, 'Delete');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete file?'), findsOneWidget);
    expect(
      find.text(
        'Could not delete logo.png. You don\'t have permission to do that.',
      ),
      findsOneWidget,
    );
    expect(repository.queries.length, loads);
  });

  testWidgets('cancelling the delete keeps the file', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseInMenu(tester, 'Delete');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.deletes, isEmpty);
    expect(find.text('logo.png'), findsOneWidget);
  });

  testWidgets('deleted files can only be deleted permanently', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);

    await tester.tap(find.text('Deleted files'));
    await tester.pumpAndSettle();
    await openFilesTab(tester);

    await tester.tap(actionsMenu());
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsNothing);
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(find.text('Delete file permanently?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletes, [('f-1', true)]);
    expect(find.text('Deleted logo.png permanently.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  Finder renameField() => find.descendant(
    of: find.byType(RenameFileDialog),
    matching: find.byType(TextField),
  );

  testWidgets('renames a file', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);
    await openFilesTab(tester);
    final loads = repository.queries.length;

    await chooseInMenu(tester, 'Rename');
    expect(find.text('Rename file'), findsOneWidget);
    await tester.enterText(renameField(), 'brand.png');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();

    expect(repository.renames, [('f-1', 'brand.png')]);
    expect(find.text('Rename file'), findsNothing);
    expect(find.text('Renamed logo.png to brand.png.'), findsOneWidget);
    expect(repository.queries.length, loads + 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('keeping the same name renames nothing', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseInMenu(tester, 'Rename');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();

    expect(repository.renames, isEmpty);
    expect(find.text('Rename file'), findsNothing);
  });

  testWidgets('an empty name cannot be saved', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseInMenu(tester, 'Rename');
    await tester.enterText(renameField(), '   ');
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Rename'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a failed rename keeps the dialog open with the reason', (
    tester,
  ) async {
    final repository = _FakeFilesRepository()
      ..renameResult = const Failure(
        ApiFailure(
          message: 'A file with this name already exists',
          kind: ApiFailureKind.client,
        ),
      );
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseInMenu(tester, 'Rename');
    await tester.enterText(renameField(), 'brand.png');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();

    expect(find.text('Rename file'), findsOneWidget);
    expect(
      find.text(
        'Could not rename logo.png. A file with this name already exists',
      ),
      findsOneWidget,
    );
    expect(find.text('logo.png'), findsOneWidget);
  });

  testWidgets('deleted files cannot be renamed', (tester) async {
    await _pump(tester, _FakeFilesRepository());

    await tester.tap(find.text('Deleted files'));
    await tester.pumpAndSettle();
    await openFilesTab(tester);
    await tester.tap(actionsMenu());
    await tester.pumpAndSettle();

    expect(find.text('Rename'), findsNothing);
  });

  Finder moveButton() => find.widgetWithText(FilledButton, 'Move');

  testWidgets('moves a file into a folder', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);
    await openFilesTab(tester);
    final fileLoads = repository.queries.length;

    await chooseInMenu(tester, 'Move');
    expect(find.text('Move logo.png'), findsOneWidget);
    // Nothing is chosen yet.
    expect(tester.widget<FilledButton>(moveButton()).onPressed, isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(MoveFileDialog),
        matching: find.text('docs'),
      ),
    );
    await tester.pump();
    await tester.tap(moveButton());
    await tester.pumpAndSettle();

    expect(repository.moves, [('f-1', 'docs')]);
    expect(find.text('Move logo.png'), findsNothing);
    expect(find.text('Moved logo.png to docs.'), findsOneWidget);
    expect(repository.queries.length, fileLoads + 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed move keeps the dialog open with the reason', (
    tester,
  ) async {
    final repository = _FakeFilesRepository()
      ..moveResult = const Failure(
        ApiFailure(message: 'nope', kind: ApiFailureKind.forbidden),
      );
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseInMenu(tester, 'Move');
    await tester.tap(
      find.descendant(
        of: find.byType(MoveFileDialog),
        matching: find.text('docs'),
      ),
    );
    await tester.pump();
    await tester.tap(moveButton());
    await tester.pumpAndSettle();

    expect(find.text('Move logo.png'), findsOneWidget);
    expect(
      find.text(
        'Could not move logo.png. You don\'t have permission to do that.',
      ),
      findsOneWidget,
    );
  });

  Finder inMoveDialog(Finder finder) =>
      find.descendant(of: find.byType(MoveFileDialog), matching: finder);

  testWidgets('the folder a file is in is not offered, but can be opened', (
    tester,
  ) async {
    final repository = _FakeFilesRepository()
      ..subfolders['docs'] = const [FileFolder(id: 'drafts', name: 'drafts')];
    await _pump(tester, repository);

    // spec.pdf is inside docs, the only top-level folder.
    await tester.tap(find.text('docs'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More actions for spec.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();

    expect(inMoveDialog(find.text('The file is already here')), findsOneWidget);
    await tester.tap(inMoveDialog(find.text('docs')));
    await tester.pump();
    expect(tester.widget<FilledButton>(moveButton()).onPressed, isNull);

    // Its subfolders can still be chosen.
    await tester.tap(find.byTooltip('Open docs'));
    await tester.pumpAndSettle();
    await tester.tap(inMoveDialog(find.text('drafts')));
    await tester.pump();
    await tester.tap(moveButton());
    await tester.pumpAndSettle();

    expect(repository.moves, [('f-2', 'drafts')]);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('moves a file into a subfolder', (tester) async {
    final repository = _FakeFilesRepository()
      ..subfolders['docs'] = const [FileFolder(id: 'logos', name: 'Logos')];
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseInMenu(tester, 'Move');
    // Only the top level is listed until a folder is opened.
    expect(inMoveDialog(find.text('Logos')), findsNothing);

    await tester.tap(find.byTooltip('Open docs'));
    await tester.pumpAndSettle();

    expect(repository.folderRequests, contains((FilesScope.all, 'docs')));
    expect(inMoveDialog(find.text('All folders')), findsOneWidget);
    await tester.tap(inMoveDialog(find.text('Logos')));
    await tester.pump();
    await tester.tap(moveButton());
    await tester.pumpAndSettle();

    expect(repository.moves, [('f-1', 'logos')]);
    expect(find.text('Moved logo.png to Logos.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('the breadcrumb goes back up and clears the choice', (
    tester,
  ) async {
    final repository = _FakeFilesRepository()
      ..subfolders['docs'] = const [FileFolder(id: 'logos', name: 'Logos')];
    await _pump(tester, repository);
    await openFilesTab(tester);
    await chooseInMenu(tester, 'Move');

    await tester.tap(find.byTooltip('Open docs'));
    await tester.pumpAndSettle();
    await tester.tap(inMoveDialog(find.text('Logos')));
    await tester.pump();
    await tester.tap(inMoveDialog(find.text('All folders')));
    await tester.pumpAndSettle();

    expect(inMoveDialog(find.text('docs')), findsOneWidget);
    expect(inMoveDialog(find.text('Logos')), findsNothing);
    expect(inMoveDialog(find.text('All folders')), findsNothing);
    expect(tester.widget<FilledButton>(moveButton()).onPressed, isNull);
  });

  testWidgets('a folder that fails to load can be retried', (tester) async {
    final repository = _FakeFilesRepository()
      ..subfolders['docs'] = const [FileFolder(id: 'logos', name: 'Logos')]
      ..failingFolderLevels.add('docs');
    await _pump(tester, repository);
    await openFilesTab(tester);
    await chooseInMenu(tester, 'Move');

    await tester.tap(find.byTooltip('Open docs'));
    await tester.pumpAndSettle();
    expect(inMoveDialog(find.text('Could not load folders.')), findsOneWidget);

    final topLevelLoads = repository.folderRequests
        .where((r) => r.$2 == null)
        .length;
    repository.failingFolderLevels.clear();
    await tester.tap(inMoveDialog(find.text('Retry')));
    await tester.pumpAndSettle();

    expect(inMoveDialog(find.text('Logos')), findsOneWidget);
    // Retry reloads only the level that failed.
    expect(
      repository.folderRequests.where((r) => r.$2 == null).length,
      topLevelLoads,
    );
  });

  testWidgets('an empty folder says so', (tester) async {
    await _pump(tester, _FakeFilesRepository());
    await openFilesTab(tester);
    await chooseInMenu(tester, 'Move');

    await tester.tap(find.byTooltip('Open docs'));
    await tester.pumpAndSettle();

    expect(inMoveDialog(find.text('No folders inside docs.')), findsOneWidget);
  });

  testWidgets('deleted files cannot be moved', (tester) async {
    await _pump(tester, _FakeFilesRepository());

    await tester.tap(find.text('Deleted files'));
    await tester.pumpAndSettle();
    await openFilesTab(tester);
    await tester.tap(actionsMenu());
    await tester.pumpAndSettle();

    expect(find.text('Move'), findsNothing);
  });

  Finder peopleField() => find.byKey(const ValueKey('share-people-field'));
  Finder sendButton() => find.widgetWithText(FilledButton, 'Send');

  Future<void> addPerson(
    WidgetTester tester,
    String search,
    String name,
  ) async {
    await tester.enterText(peopleField(), search);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  testWidgets('Share is offered only on files you uploaded', (tester) async {
    final repository = _FakeFilesRepository()
      ..moreFiles = [
        const WorkspaceFile(id: 'f-2', name: 'brief.pdf', userId: 'u-2'),
      ];
    await _pump(tester, repository);
    await openFilesTab(tester);

    await tester.tap(find.byTooltip('More actions for brief.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.tap(actionsMenu());
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('shares a file with a member by direct message', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseInMenu(tester, 'Share');
    expect(find.text('Share logo.png'), findsOneWidget);
    expect(tester.widget<FilledButton>(sendButton()).onPressed, isNull);

    await addPerson(tester, 'gra', 'Grace Hopper');
    await tester.tap(find.text('Can view'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Can edit').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('share-note-field')),
      'For the review',
    );
    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    final (fileId, recipientIds, permission, access, note) =
        repository.shares.single;
    expect(fileId, 'f-1');
    expect(recipientIds, ['u-2']);
    expect(permission, FileSharePermission.edit);
    expect(access, FileShareAccess.invited);
    expect(note, 'For the review');
    expect(find.text('Share logo.png'), findsNothing);
    expect(
      find.text('Shared logo.png with Grace Hopper by direct message.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a picked member can be removed before sending', (tester) async {
    await _pump(tester, _FakeFilesRepository());
    await openFilesTab(tester);
    await chooseInMenu(tester, 'Share');

    await addPerson(tester, 'gra', 'Grace Hopper');
    expect(find.byType(InputChip), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Grace Hopper'));
    await tester.pumpAndSettle();

    expect(find.byType(InputChip), findsNothing);
    expect(tester.widget<FilledButton>(sendButton()).onPressed, isNull);
  });

  testWidgets('says when nobody in the workspace matches', (tester) async {
    await _pump(tester, _FakeFilesRepository());
    await openFilesTab(tester);
    await chooseInMenu(tester, 'Share');

    await tester.enterText(peopleField(), 'nobody');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('No workspace member matches.'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No workspace member matches "nobody". '
        'Only workspace members can receive shared files.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reports people the file could not be sent to', (tester) async {
    final repository = _FakeFilesRepository()
      ..shareResult = const Success(
        FileShareResult(
          sentTo: ['u-2'],
          recipients: [
            FileShareRecipientResult(userId: 'u-2', success: true),
            FileShareRecipientResult(userId: 'u-3', error: 'DM blocked'),
          ],
        ),
      );
    await _pump(tester, repository);
    await openFilesTab(tester);
    await chooseInMenu(tester, 'Share');

    await addPerson(tester, 'gra', 'Grace Hopper');
    await addPerson(tester, 'ala', 'Alan Turing');
    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    expect(repository.shares.single.$2, ['u-2', 'u-3']);
    expect(
      find.text('Shared logo.png with 1 of 2 people. Alan Turing: DM blocked.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed share keeps the dialog open with the reason', (
    tester,
  ) async {
    final repository = _FakeFilesRepository()
      ..shareResult = const Failure(
        ApiFailure(message: 'Access denied', kind: ApiFailureKind.forbidden),
      );
    await _pump(tester, repository);
    await openFilesTab(tester);
    await chooseInMenu(tester, 'Share');

    await addPerson(tester, 'gra', 'Grace Hopper');
    await tester.tap(sendButton());
    await tester.pumpAndSettle();

    expect(find.text('Share logo.png'), findsOneWidget);
    expect(
      find.text('Could not share logo.png. Only its owner can share it.'),
      findsOneWidget,
    );
  });

  testWidgets('deleted files cannot be shared', (tester) async {
    await _pump(tester, _FakeFilesRepository());

    await tester.tap(find.text('Deleted files'));
    await tester.pumpAndSettle();
    await openFilesTab(tester);
    await tester.tap(actionsMenu());
    await tester.pumpAndSettle();

    expect(find.text('Share'), findsNothing);
  });

  Finder pinMarker() => find.byTooltip('Pinned');

  testWidgets('pins a file under Pinned files', (tester) async {
    final repository = _FakeFilesRepository()
      ..moreFiles = [const WorkspaceFile(id: 'f-3', name: 'notes.txt')];
    await _pump(tester, repository);
    await openFilesTab(tester);

    expect(find.text('Pinned files'), findsNothing);
    expect(pinMarker(), findsNothing);

    await chooseInMenu(tester, 'Pin');

    expect(repository.pinCalls, [('f-1', true)]);
    expect(find.text('Pinned files'), findsOneWidget);
    expect(pinMarker(), findsOneWidget);
    // The pinned file comes first, above the others.
    expect(
      tester.getTopLeft(find.text('logo.png')).dy,
      lessThan(tester.getTopLeft(find.text('notes.txt')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Pinned files')).dy,
      lessThan(tester.getTopLeft(find.text('logo.png')).dy),
    );
  });

  testWidgets('pins kept on the server show when the page opens', (
    tester,
  ) async {
    final repository = _FakeFilesRepository()..pinnedIds = {'f-1'};
    await _pump(tester, repository);
    await openFilesTab(tester);

    expect(find.text('Pinned files'), findsOneWidget);
    expect(pinMarker(), findsOneWidget);

    await tester.tap(actionsMenu());
    await tester.pumpAndSettle();
    expect(find.text('Pin'), findsNothing);
    await tester.tap(find.text('Unpin'));
    await tester.pumpAndSettle();

    expect(repository.pinCalls, [('f-1', false)]);
    expect(find.text('Pinned files'), findsNothing);
    expect(pinMarker(), findsNothing);
  });

  testWidgets('a failed pin is undone with the reason', (tester) async {
    final repository = _FakeFilesRepository()
      ..pinResult = const Failure(
        ApiFailure(message: 'offline', kind: ApiFailureKind.network),
      );
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseInMenu(tester, 'Pin');

    expect(find.text('Pinned files'), findsNothing);
    expect(pinMarker(), findsNothing);
    expect(
      find.text(
        'Could not pin logo.png. '
        'No internet connection. Check your network and try again.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('deleted files cannot be pinned', (tester) async {
    await _pump(tester, _FakeFilesRepository()..pinnedIds = {'f-1'});

    await tester.tap(find.text('Deleted files'));
    await tester.pumpAndSettle();
    await openFilesTab(tester);

    expect(find.text('Pinned files'), findsNothing);
    await tester.tap(actionsMenu());
    await tester.pumpAndSettle();
    expect(find.text('Pin'), findsNothing);
    expect(find.text('Unpin'), findsNothing);
  });

  Finder infoPanel() => find.byType(FileInfoPanel);
  Finder inPanel(String text) =>
      find.descendant(of: infoPanel(), matching: find.text(text));

  testWidgets('Info shows the file details and closes', (tester) async {
    final repository = _FakeFilesRepository();
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseInMenu(tester, 'Info');

    expect(repository.detailRequests, ['f-1']);
    expect(infoPanel(), findsOneWidget);
    expect(inPanel('Info'), findsOneWidget);
    expect(inPanel('logo.png'), findsOneWidget);
    expect(inPanel('PNG'), findsOneWidget);
    expect(inPanel('Ada Lovelace'), findsOneWidget);
    expect(inPanel('Private'), findsOneWidget);
    expect(inPanel('Oct 30, 2026, 2:05 PM'), findsOneWidget);
    expect(inPanel('Nov 1, 2026, 9:30 AM'), findsOneWidget);
    expect(inPanel('general'), findsOneWidget);
    expect(inPanel('2 KB'), findsOneWidget);
    expect(inPanel('All files'), findsOneWidget);

    await tester.tap(find.byTooltip('Close file info'));
    await tester.pumpAndSettle();

    expect(infoPanel(), findsNothing);
    expect(find.text('logo.png'), findsOneWidget);
  });

  testWidgets('Info shows the list details when the server fails', (
    tester,
  ) async {
    final repository = _FakeFilesRepository()
      ..details = (Completer()
        ..complete(
          const Failure(
            ApiFailure(message: 'offline', kind: ApiFailureKind.network),
          ),
        ));
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseInMenu(tester, 'Info');

    expect(inPanel('logo.png'), findsOneWidget);
    expect(inPanel('2 KB'), findsOneWidget);
    // The list does not know the access type, so it is left out.
    expect(inPanel('Access'), findsNothing);
    expect(
      inPanel('Could not load the latest details. Showing what the list has.'),
      findsOneWidget,
    );

    repository.details = Completer()
      ..complete(
        const Success(
          WorkspaceFile(id: 'f-1', name: 'logo.png', accessType: 'public'),
        ),
      );
    await tester.tap(inPanel('Retry'));
    await tester.pumpAndSettle();

    expect(inPanel('Public'), findsOneWidget);
    expect(find.textContaining('Could not load'), findsNothing);
  });

  testWidgets('Info names the folder a file is in', (tester) async {
    final repository = _FakeFilesRepository()
      ..details = (Completer()
        ..complete(
          const Success(
            WorkspaceFile(id: 'f-2', name: 'spec.pdf', folderId: 'docs'),
          ),
        ));
    await _pump(tester, repository);

    await tester.tap(find.text('docs'));
    await tester.pumpAndSettle();
    await openFilesTab(tester);
    await tester.tap(find.byTooltip('More actions for spec.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();

    expect(inPanel('docs'), findsOneWidget);
    expect(inPanel('No preview available'), findsOneWidget);
  });

  testWidgets('deleted files have no Info', (tester) async {
    await _pump(tester, _FakeFilesRepository());

    await tester.tap(find.text('Deleted files'));
    await tester.pumpAndSettle();
    await openFilesTab(tester);
    await tester.tap(actionsMenu());
    await tester.pumpAndSettle();

    expect(find.text('Info'), findsNothing);
  });

  // A 1×1 PNG.
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  );
  Finder previewDialog() => find.byType(FilePreviewDialog);
  Finder inPreview(String text) =>
      find.descendant(of: previewDialog(), matching: find.text(text));

  testWidgets('clicking a text file previews its contents', (tester) async {
    final repository = _FakeFilesRepository()
      ..moreFiles = [
        const WorkspaceFile(id: 'f-3', name: 'notes.txt', fileType: 'txt'),
      ];
    await _pump(tester, repository);
    await openFilesTab(tester);

    await tester.tap(find.text('notes.txt'));
    await tester.pumpAndSettle();

    expect(repository.previews, [('f-3', FilePreviewKind.text)]);
    expect(inPreview('notes.txt'), findsOneWidget);
    expect(inPreview('hello from the file'), findsOneWidget);
    // Text has no zoom.
    expect(find.byTooltip('Zoom in'), findsNothing);

    await tester.tap(find.byTooltip('Close preview (Esc)'));
    await tester.pumpAndSettle();
    expect(previewDialog(), findsNothing);
  });

  testWidgets('Preview shows an image that can be zoomed', (tester) async {
    final repository = _FakeFilesRepository()..preview = (_) => Success(png);
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseInMenu(tester, 'Preview');

    expect(repository.previews, [('f-1', FilePreviewKind.image)]);
    expect(
      find.descendant(of: previewDialog(), matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(inPreview('100%'), findsOneWidget);

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    expect(inPreview('125%'), findsOneWidget);

    await tester.tap(find.byTooltip('Fit to window'));
    await tester.pumpAndSettle();
    expect(inPreview('100%'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(previewDialog(), findsNothing);
  });

  testWidgets('files that cannot be previewed say so and offer Download', (
    tester,
  ) async {
    final repository = _FakeFilesRepository()
      ..moreFiles = [
        const WorkspaceFile(id: 'f-4', name: 'deck.pptx', fileType: 'pptx'),
      ];
    await _pump(tester, repository, savePath: '/Users/ada/Downloads/deck.pptx');
    await openFilesTab(tester);

    await tester.tap(find.text('deck.pptx'));
    await tester.pumpAndSettle();

    expect(repository.previews, isEmpty);
    expect(inPreview('No preview available'), findsOneWidget);
    expect(
      inPreview(
        'Preview isn’t available for .pptx files. '
        'Download it or open it in your browser.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: previewDialog(),
        matching: find.widgetWithText(OutlinedButton, 'Download'),
      ),
    );
    await tester.pumpAndSettle();

    expect(previewDialog(), findsNothing);
    expect(repository.downloads, [('f-4', '/Users/ada/Downloads/deck.pptx')]);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed preview can be retried', (tester) async {
    var fail = true;
    final repository = _FakeFilesRepository()
      ..moreFiles = [
        const WorkspaceFile(id: 'f-3', name: 'notes.txt', fileType: 'txt'),
      ]
      ..preview = (_) => fail
          ? const Failure(
              ApiFailure(message: 'offline', kind: ApiFailureKind.network),
            )
          : Success(Uint8List.fromList(utf8.encode('back online')));
    await _pump(tester, repository);
    await openFilesTab(tester);

    await tester.tap(find.text('notes.txt'));
    await tester.pumpAndSettle();
    expect(inPreview('Could not load the preview'), findsOneWidget);
    expect(
      inPreview('No internet connection. Check your network and try again.'),
      findsOneWidget,
    );

    fail = false;
    await tester.tap(inPreview('Retry'));
    await tester.pumpAndSettle();

    expect(inPreview('back online'), findsOneWidget);
    expect(repository.previews, hasLength(2));
  });

  testWidgets('a file too large to preview offers Download only', (
    tester,
  ) async {
    final repository = _FakeFilesRepository()
      ..preview = (_) => const Failure(
        ApiFailure(
          message: 'This file is too large to preview.',
          kind: ApiFailureKind.client,
        ),
      );
    await _pump(tester, repository);
    await openFilesTab(tester);

    await chooseInMenu(tester, 'Preview');

    expect(
      inPreview('This file is too large to preview. Download it instead.'),
      findsOneWidget,
    );
    expect(inPreview('Retry'), findsNothing);
  });

  testWidgets('deleted files have no Preview', (tester) async {
    await _pump(tester, _FakeFilesRepository());

    await tester.tap(find.text('Deleted files'));
    await tester.pumpAndSettle();
    await openFilesTab(tester);
    await tester.tap(actionsMenu());
    await tester.pumpAndSettle();

    expect(find.text('Preview'), findsNothing);
  });

  testWidgets('PDFs are not previewed yet and can open in the browser', (
    tester,
  ) async {
    final repository = _FakeFilesRepository()
      ..moreFiles = [
        const WorkspaceFile(id: 'f-5', name: 'report.pdf', fileType: 'pdf'),
      ];
    await _pump(tester, repository);
    await openFilesTab(tester);

    await tester.tap(find.text('report.pdf'));
    await tester.pumpAndSettle();

    expect(repository.previews, isEmpty);
    expect(inPreview('No preview available'), findsOneWidget);
    expect(
      find.descendant(
        of: previewDialog(),
        matching: find.widgetWithText(TextButton, 'Open in browser'),
      ),
      findsOneWidget,
    );
  });
}
