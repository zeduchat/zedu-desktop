import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

Widget _viewer({ImageDownloadCallback? onDownload}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => ImageAttachmentViewer(
                  imageUrl: 'https://example.com/photo.png',
                  fileName: 'photo.png',
                  onDownload: onDownload,
                ),
              ),
            ),
            child: const Text('Open image'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openViewer(
  WidgetTester tester, {
  ImageDownloadCallback? onDownload,
}) async {
  await tester.pumpWidget(_viewer(onDownload: onDownload));
  await tester.tap(find.text('Open image'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the image full screen and closes', (tester) async {
    await _openViewer(tester);

    expect(find.text('photo.png'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Rotate image'), findsOneWidget);
    expect(find.byTooltip('Save image'), findsOneWidget);

    await tester.tap(find.byTooltip('Close image viewer'));
    await tester.pumpAndSettle();

    expect(find.text('photo.png'), findsNothing);
    expect(find.text('Open image'), findsOneWidget);
  });

  testWidgets('zoom in and out change the viewer scale', (tester) async {
    await _openViewer(tester);
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;

    expect(controller.value.getMaxScaleOnAxis(), 1);

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1.5, 0.001));

    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1, 0.001));
  });

  testWidgets('rotate turns the image a quarter at a time', (tester) async {
    await _openViewer(tester);

    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 0);

    await tester.tap(find.byTooltip('Rotate image'));
    await tester.pump();

    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 1);
  });

  testWidgets('save uses the download callback and confirms', (tester) async {
    String? downloadedUrl;
    String? downloadedName;
    await _openViewer(
      tester,
      onDownload: (url, fileName) async {
        downloadedUrl = url;
        downloadedName = fileName;
        return true;
      },
    );

    await tester.tap(find.byTooltip('Save image'));
    await tester.pump();
    await tester.pump();

    expect(downloadedUrl, 'https://example.com/photo.png');
    expect(downloadedName, 'photo.png');
    expect(find.text('Saved photo.png'), findsOneWidget);
  });

  testWidgets('save reports a failure without closing the viewer', (
    tester,
  ) async {
    await _openViewer(tester, onDownload: (_, _) async => false);

    await tester.tap(find.byTooltip('Save image'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Could not save photo.png'), findsOneWidget);
    expect(find.text('photo.png'), findsOneWidget);
  });
}
