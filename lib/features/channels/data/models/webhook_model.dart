/// A webhook configured for a channel.
class WebhookModel {
  const WebhookModel({
    required this.id,
    required this.channelId,
    required this.name,
    required this.slug,
    required this.url,
    this.isActive = false,
    this.createdAt,
  });

  final String id;
  final String channelId;
  final String name;
  final String slug;
  final String url;
  final bool isActive;
  final DateTime? createdAt;

  /// Reads both this app's field names and the backend's (`webhook_name`,
  /// `webhook_url`, `webhook_slug`, and `status` of `active` or `inactive`).
  factory WebhookModel.fromJson(Map<String, dynamic> json) {
    return WebhookModel(
      id: _asString(json['id']),
      channelId: _asString(json['channelId'] ?? json['channel_id']),
      name: _asString(json['name'] ?? json['webhook_name']),
      slug: _asString(json['slug'] ?? json['webhook_slug']),
      url: _asString(json['url'] ?? json['webhook_url']),
      isActive: json.containsKey('status')
          ? json['status']?.toString().toLowerCase() == 'active'
          : _asBool(json['isActive'] ?? json['is_active']),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'channelId': channelId,
    'name': name,
    'slug': slug,
    'url': url,
    'isActive': isActive,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}

String _asString(Object? value) => value?.toString() ?? '';

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
