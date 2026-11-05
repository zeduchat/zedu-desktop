/// An organisation AI bot/agent.
class AgentModel {
  const AgentModel({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    this.avatarUrl,
    this.isActive = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final String? avatarUrl;
  final bool isActive;
  final DateTime? createdAt;

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      id: _asString(json['id']),
      name: _asString(json['name']),
      description: _asString(json['description']),
      systemPrompt: _asString(json['systemPrompt'] ?? json['system_prompt']),
      avatarUrl: _asNullableString(json['avatarUrl'] ?? json['avatar_url']),
      isActive: _asBool(json['isActive'] ?? json['is_active']),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'systemPrompt': systemPrompt,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'isActive': isActive,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}

String _asString(Object? value) => value?.toString() ?? '';

String? _asNullableString(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

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
