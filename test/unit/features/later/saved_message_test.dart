import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/later/domain/saved_message.dart';

void main() {
  test('uses thread identity for saved top-level messages', () {
    final message = SavedMessage.fromJson({
      'id': 'bookmark',
      'thread_id': 'thread',
      'channels_id': 'channel',
      'message': 'hello',
    });
    expect(message.id, 'thread');
    expect(message.channelId, 'channel');
    expect(message.preview, 'hello');
  });
  test('supports direct-message metadata and unavailable content', () {
    final message = SavedMessage.fromJson({
      'id': 'm1',
      'channel_type': 'Direct Message',
    });
    expect(message.isDm, isTrue);
    expect(message.preview, isEmpty);
    expect(message.channelId, isEmpty);
  });
}
