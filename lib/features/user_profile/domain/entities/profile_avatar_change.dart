import 'package:zedu/core/core.dart';

/// A change to the signed-in user's profile photo: a new image to upload, or
/// removal of the current one.
class ProfileAvatarChange {
  /// Uploads [bytes] (a PNG or JPEG named [fileName]) as the new photo.
  const ProfileAvatarChange.upload({
    required Uint8List this.bytes,
    required String this.fileName,
  });

  /// Removes the current photo.
  const ProfileAvatarChange.remove() : bytes = null, fileName = null;

  /// The largest photo the API accepts.
  static const int maxBytes = 5 * 1024 * 1024;

  /// The file types the API accepts (zedu-be `ValidatePicture`).
  static const List<String> allowedExtensions = ['png', 'jpg', 'jpeg'];

  final Uint8List? bytes;
  final String? fileName;

  bool get isRemoval => bytes == null;

  /// The image's MIME type, read from [fileName]. zedu-be ignores an upload
  /// whose part is not `image/png` or `image/jpeg`.
  String get mimeType => (fileName ?? '').toLowerCase().endsWith('.png')
      ? 'image/png'
      : 'image/jpeg';
}
