import 'dart:io';

import 'package:zedu/core/core.dart';

/// Downloads [url] and saves it as [fileName]. Returns whether the file was
/// saved, so tests can replace the platform picker and network call.
typedef ImageDownloadCallback =
    Future<bool> Function(String url, String fileName);

/// Full-screen viewer for an image attachment.
///
/// The attachment is shown over a dark backdrop and can be zoomed, rotated and
/// saved. Pass [onDownload] in tests to avoid opening the platform save dialog.
class ImageAttachmentViewer extends StatefulWidget {
  const ImageAttachmentViewer({
    super.key,
    required this.imageUrl,
    required this.fileName,
    this.onDownload,
  });

  /// Network URL or bundled asset path of the image.
  final String imageUrl;

  /// Name used for the save dialog and the viewer title.
  final String fileName;

  final ImageDownloadCallback? onDownload;

  @override
  State<ImageAttachmentViewer> createState() => _ImageAttachmentViewerState();
}

class _ImageAttachmentViewerState extends State<ImageAttachmentViewer> {
  static const _minScale = 0.5;
  static const _maxScale = 4.0;

  final _transformationController = TransformationController();
  double _scale = 1;
  int _quarterTurns = 0;
  bool _saving = false;

  bool get _isNetwork => widget.imageUrl.startsWith('http');

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _zoomBy(double factor) {
    final next = (_scale * factor).clamp(_minScale, _maxScale);
    if (next == _scale) return;
    _transformationController.value = Matrix4.diagonal3Values(next, next, 1);
    setState(() => _scale = next);
  }

  void _rotate() {
    setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final download = widget.onDownload ?? _download;
    final saved = await download(widget.imageUrl, widget.fileName);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Saved ${widget.fileName}'
                : 'Could not save ${widget.fileName}',
          ),
        ),
      );
  }

  Future<bool> _download(String url, String fileName) async {
    try {
      final bytes = await _readBytes(url);
      if (bytes.isEmpty) return false;
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save image',
        fileName: fileName,
        type: FileType.image,
      );
      if (path == null) return false;
      await File(path).writeAsBytes(bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> _readBytes(String url) async {
    if (_isNetwork) {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const []);
    }
    final data = await rootBundle.load(url);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Widget _buildImage(AppPalette colors) {
    Widget errorBuilder(
      BuildContext context,
      Object error,
      StackTrace? stackTrace,
    ) => Icon(
      Icons.broken_image_outlined,
      color: colors.onPrimary.withValues(alpha: 0.7),
      size: 64,
    );
    if (_isNetwork) {
      return Image.network(
        widget.imageUrl,
        fit: BoxFit.contain,
        errorBuilder: errorBuilder,
      );
    }
    return Image.asset(
      widget.imageUrl,
      fit: BoxFit.contain,
      errorBuilder: errorBuilder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final iconColor = colors.onPrimary;
    return Scaffold(
      backgroundColor: colors.textPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: _minScale,
                maxScale: _maxScale,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: _quarterTurns,
                    child: _buildImage(colors),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close image viewer',
                    icon: Icon(Icons.close_rounded, color: iconColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Zoom out',
                    icon: Icon(Icons.zoom_out_rounded, color: iconColor),
                    onPressed: _scale <= _minScale
                        ? null
                        : () => _zoomBy(1 / 1.5),
                  ),
                  IconButton(
                    tooltip: 'Zoom in',
                    icon: Icon(Icons.zoom_in_rounded, color: iconColor),
                    onPressed: _scale >= _maxScale ? null : () => _zoomBy(1.5),
                  ),
                  IconButton(
                    tooltip: 'Rotate image',
                    icon: Icon(Icons.rotate_right_rounded, color: iconColor),
                    onPressed: _rotate,
                  ),
                  IconButton(
                    tooltip: 'Save image',
                    icon: _saving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: iconColor,
                            ),
                          )
                        : Icon(Icons.download_rounded, color: iconColor),
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
