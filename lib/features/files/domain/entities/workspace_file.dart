/// A file in the workspace's Files area.
class WorkspaceFile {
  final String id;
  final String name;

  /// Lower-case extension, such as `png` or `pdf`. Empty when unknown.
  final String fileType;
  final String mimeType;
  final String link;

  /// Size in bytes.
  final int size;
  final String userId;
  final String folderId;

  /// Channel the file was shared in, or empty.
  final String sharedIn;

  /// Uploader's display name, or empty.
  final String owner;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkspaceFile({
    required this.id,
    required this.name,
    this.fileType = '',
    this.mimeType = '',
    this.link = '',
    this.size = 0,
    this.userId = '',
    this.folderId = '',
    this.sharedIn = '',
    this.owner = '',
    this.createdAt,
    this.updatedAt,
  });

  static const _imageTypes = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'};

  bool get isImage =>
      _imageTypes.contains(fileType) || mimeType.startsWith('image/');

  /// When the file last changed, falling back to when it was uploaded.
  DateTime? get modifiedAt => updatedAt ?? createdAt;

  factory WorkspaceFile.fromJson(Map<String, dynamic> json) {
    String text(List<String> keys) {
      for (final key in keys) {
        final value = json[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final name = text(['file_name']);
    final mimeType = text(['mime_type']).toLowerCase();
    return WorkspaceFile(
      id: text(['id']),
      name: name.isNotEmpty ? name : 'Untitled file',
      fileType: _fileType(text(['file_type']), name),
      mimeType: mimeType,
      link: text(['file_link']),
      size: num.tryParse(json['size']?.toString() ?? '')?.toInt() ?? 0,
      userId: text(['user_id']),
      folderId: text(['folder_id']),
      sharedIn: text(['shared_in', 'sharedIn', 'channel_name']),
      owner: text(['uploader_display_name', 'owner']),
      createdAt: DateTime.tryParse(text(['created_at']))?.toLocal(),
      updatedAt: DateTime.tryParse(text(['updated_at']))?.toLocal(),
    );
  }
}

String _fileType(String fileType, String fileName) {
  final type = fileType.toLowerCase();
  if (type.isNotEmpty) {
    // Accept a MIME type such as `image/png` as well as a bare extension.
    return type.contains('/') ? type.split('/').last : type;
  }
  final dot = fileName.lastIndexOf('.');
  return dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
}
