import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/home/data/services/chat_websocket_service.dart';

ChatWebsocketMessage _message(String text) => ChatWebsocketMessage(
  groupDmId: 'group-a',
  text: text,
  authorName: 'Ada',
  timestamp: DateTime(2026, 11, 3),
);

void main() {
  group('ChatWebsocketService messages', () {
    // testWidgets runs on a fake clock, so a minute passes instantly.
    testWidgets('never invents messages after connecting', (tester) async {
      final service = ChatWebsocketService();
      addTearDown(service.dispose);
      final received = <ChatWebsocketMessage>[];
      final sub = service.messageStream.listen(received.add);
      addTearDown(sub.cancel);

      service.connect(['group-a', 'group-b']);
      await tester.pump(const Duration(minutes: 1));

      expect(received, isEmpty);
    });

    testWidgets('passes on messages it is given', (tester) async {
      final service = ChatWebsocketService();
      addTearDown(service.dispose);
      final received = <ChatWebsocketMessage>[];
      final sub = service.messageStream.listen(received.add);
      addTearDown(sub.cancel);

      final message = _message('Hello');
      service.receive(message);
      await tester.pump();

      expect(received, [message]);
    });

    test('remembers the group DMs it is in until disconnected', () {
      final service = ChatWebsocketService();
      addTearDown(service.dispose);

      service.connect(['group-a']);
      expect(service.activeGroupDmIds, ['group-a']);

      service.disconnect();
      expect(service.activeGroupDmIds, isEmpty);
    });

    test('ignores messages after it is disposed', () {
      final service = ChatWebsocketService()..dispose();

      expect(() => service.receive(_message('Late')), returnsNormally);
    });
  });

  // From #2273: the service must stay safe to use around dispose.
  group('ChatWebsocketService lifecycle', () {
    late ChatWebsocketService service;

    setUp(() {
      service = ChatWebsocketService();
    });

    tearDown(() {
      if (!service.isDisposed) {
        service.dispose();
      }
    });

    test('initial state is not disposed and has no pending connect', () {
      expect(service.isDisposed, isFalse);
      expect(service.hasPendingConnect, isFalse);
    });

    test('connect schedules no timer (there is no simulated socket)', () {
      service.connect(['group-1']);

      expect(service.hasPendingConnect, isFalse);
      expect(service.isDisposed, isFalse);
    });

    test('connect then dispose leaves nothing running', () async {
      service.connect(['group-1', 'group-2']);
      service.dispose();
      expect(service.isDisposed, isTrue);
      expect(service.hasPendingConnect, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(service.isDisposed, isTrue);
    });

    test('calling connect on a disposed service is a safe no-op', () {
      service.dispose();
      service.connect(['group-1']);

      expect(service.activeGroupDmIds, isEmpty);
      expect(service.hasPendingConnect, isFalse);
    });

    test('disconnect and dispose can be called multiple times safely', () {
      service.disconnect();
      service.disconnect();
      service.dispose();
      service.dispose();

      expect(service.isDisposed, isTrue);
    });

    test('sendMessage is a safe call', () {
      expect(() => service.sendMessage('group-1', 'hello'), returnsNormally);
    });
  });
}
