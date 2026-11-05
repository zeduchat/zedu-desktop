/// A folder in the workspace's Files area.
class FileFolder {
  final String id;
  final String name;
  final String userId;
  final int itemCount;
  final DateTime? createdAt;

  const FileFolder({
    required this.id,
    required this.name,
    this.userId = '',
    this.itemCount = 0,
    this.createdAt,
  });

  factory FileFolder.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString().trim() ?? '';
    return FileFolder(
      id: json['id']?.toString() ?? '',
      name: name.isNotEmpty ? name : 'Untitled folder',
      userId: json['user_id']?.toString() ?? '',
      itemCount:
          num.tryParse(json['item_count']?.toString() ?? '')?.toInt() ?? 0,
      createdAt: DateTime.tryParse(
        (json['created_at'] ?? json['dateCreated'])?.toString() ?? '',
      )?.toLocal(),
    );
  }
}
