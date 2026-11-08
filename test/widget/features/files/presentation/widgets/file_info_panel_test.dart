import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

Future<void> showFile(WidgetTester tester, WorkspaceFile file) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fileDetailsProvider(file.id).overrideWith((ref) async => file),
      ],
      child: buildTestMaterialApp(FileInfoPanel(file: file, owner: 'Grace')),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('SVG uses a vector renderer with the file semantic label', (
    tester,
  ) async {
    await HttpOverrides.runZoned(() async {
      await showFile(
        tester,
        const WorkspaceFile(
          id: 'svg',
          name: 'diagram.svg',
          fileType: 'svg',
          link: 'https://example.invalid/diagram.svg',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(
        tester.widget<SvgPicture>(find.byType(SvgPicture)).semanticsLabel,
        'diagram.svg',
      );
      expect(find.text('No preview available'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, createHttpClient: (_) => _SvgClient());
  });

  testWidgets('BMP without MIME metadata uses the raster renderer', (
    tester,
  ) async {
    await showFile(
      tester,
      const WorkspaceFile(
        id: 'bmp',
        name: 'photo.bmp',
        fileType: 'bmp',
        link: 'https://example.invalid/photo.bmp',
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
    expect(tester.widget<Image>(find.byType(Image)).semanticLabel, 'photo.bmp');
    await tester.pumpWidget(const SizedBox());
  });

  for (final file in [
    const WorkspaceFile(id: 'empty', name: 'empty.svg', fileType: 'svg'),
    const WorkspaceFile(
      id: 'pdf',
      name: 'notes.pdf',
      fileType: 'pdf',
      link: 'https://example.invalid/notes.pdf',
    ),
  ]) {
    testWidgets('keeps no-preview fallback for ${file.id}', (tester) async {
      await showFile(tester, file);
      expect(find.text('No preview available'), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.byType(Image), findsNothing);
    });
  }

  testWidgets('copy button copies file name to clipboard and shows toast', (
    tester,
  ) async {
    const file = WorkspaceFile(
      id: 'copy-test',
      name: 'quarterly_results.xlsx',
      fileType: 'xlsx',
    );
    await showFile(tester, file);
    await tester.pumpAndSettle();

    expect(find.text('quarterly_results.xlsx'), findsOneWidget);
    final copyBtn = find.byTooltip('Copy file name');
    expect(copyBtn, findsOneWidget);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        } else if (call.method == 'Clipboard.getData') {
          return <String, Object?>{'text': copied ?? ''};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.tap(copyBtn);
    await tester.pumpAndSettle();

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    expect(data?.text, 'quarterly_results.xlsx');
    expect(find.text('File name copied'), findsOneWidget);
  });
}

final _svgBytes = utf8.encode(
  '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><rect width="20" height="20" fill="blue"/></svg>',
);

class _Headers extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String, List<String>) action) {}
}

class _SvgClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _Request();
  @override
  void close({bool force = false}) {}
}

class _Request extends Fake implements HttpClientRequest {
  @override
  HttpHeaders get headers => _Headers();
  @override
  set followRedirects(bool value) {}
  @override
  set maxRedirects(int value) {}
  @override
  set contentLength(int value) {}
  @override
  set persistentConnection(bool value) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  Future<HttpClientResponse> close() async => _Response();
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _svgBytes.length;
  @override
  HttpHeaders get headers => _Headers();
  @override
  String get reasonPhrase => 'OK';
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  List<RedirectInfo> get redirects => [];
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_svgBytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
