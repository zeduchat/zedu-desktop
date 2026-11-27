/// What the Edit profile dialog did to the profile photo: nothing, picked a
/// new file to upload, or removed the current photo.
class ProfilePhotoEdit {
  const ProfilePhotoEdit._({this.filePath, this.remove = false});

  /// The photo is left as it is.
  static const unchanged = ProfilePhotoEdit._();

  /// The photo is removed.
  static const removed = ProfilePhotoEdit._(remove: true);

  /// [filePath] is uploaded as the new photo.
  const ProfilePhotoEdit.upload(String filePath) : this._(filePath: filePath);

  /// Local path of the new photo, when one was picked.
  final String? filePath;

  /// Whether the current photo is removed.
  final bool remove;

  bool get isUnchanged => filePath == null && !remove;
}
