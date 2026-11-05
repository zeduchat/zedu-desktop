import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

Channel _channel(String name, {String description = ''}) => Channel(
  id: name,
  name: name,
  description: description,
  organisationId: 'org',
  ownerId: 'owner',
);

void main() {
  final channels = [
    _channel('general', description: 'Company-wide announcements'),
    _channel('random'),
    _channel('design', description: 'UI reviews'),
  ];

  group('filterChannels', () {
    test('a query with spaces around it finds the same channel', () {
      expect(filterChannels(channels, 'general').map((c) => c.name), [
        'general',
      ]);
      expect(filterChannels(channels, ' general ').map((c) => c.name), [
        'general',
      ]);
      expect(filterChannels(channels, '\tgeneral\n').map((c) => c.name), [
        'general',
      ]);
    });

    test('name and description still match without regard to case', () {
      expect(filterChannels(channels, 'GENERAL').map((c) => c.name), [
        'general',
      ]);
      expect(filterChannels(channels, ' ui REVIEWS ').map((c) => c.name), [
        'design',
      ]);
    });

    test('an empty or blank query keeps every channel', () {
      expect(filterChannels(channels, ''), hasLength(3));
      expect(filterChannels(channels, '   '), hasLength(3));
    });

    test('a term that matches nothing still gives no results', () {
      expect(filterChannels(channels, ' marketing '), isEmpty);
    });
  });
}
