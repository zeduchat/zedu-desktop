import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('AgentModel', () {
    test('parses a full camelCase payload', () {
      final model = AgentModel.fromJson({
        'id': 'agent-1',
        'name': 'Support bot',
        'description': 'Answers common questions',
        'systemPrompt': 'Be helpful',
        'avatarUrl': 'https://cdn.example.com/bot.png',
        'isActive': true,
        'createdAt': '2026-11-04T07:30:00.000Z',
      });

      expect(model.id, 'agent-1');
      expect(model.name, 'Support bot');
      expect(model.description, 'Answers common questions');
      expect(model.systemPrompt, 'Be helpful');
      expect(model.avatarUrl, 'https://cdn.example.com/bot.png');
      expect(model.isActive, isTrue);
      expect(model.createdAt, DateTime.utc(2026, 11, 4, 7, 30));
    });

    test('parses the backend snake_case payload', () {
      final model = AgentModel.fromJson({
        'id': 'agent-2',
        'name': 'Ops bot',
        'description': 'Watches deploys',
        'system_prompt': 'Report incidents',
        'avatar_url': '',
        'is_active': 1,
        'created_at': '2026-11-04T08:00:00.000Z',
      });

      expect(model.systemPrompt, 'Report incidents');
      expect(model.avatarUrl, isNull);
      expect(model.isActive, isTrue);
      expect(model.createdAt, DateTime.utc(2026, 11, 4, 8));
    });

    test('falls back for missing optional fields', () {
      final model = AgentModel.fromJson({'id': 'agent-3'});

      expect(model.name, isEmpty);
      expect(model.description, isEmpty);
      expect(model.systemPrompt, isEmpty);
      expect(model.avatarUrl, isNull);
      expect(model.isActive, isFalse);
      expect(model.createdAt, isNull);
    });

    test('round-trips through toJson', () {
      final original = AgentModel(
        id: 'agent-4',
        name: 'Design bot',
        description: 'Reviews mockups',
        systemPrompt: 'Be concise',
        avatarUrl: 'https://cdn.example.com/design.png',
        isActive: true,
        createdAt: DateTime.utc(2026, 11, 4, 9, 15),
      );

      final restored = AgentModel.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.systemPrompt, original.systemPrompt);
      expect(restored.avatarUrl, original.avatarUrl);
      expect(restored.isActive, original.isActive);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
