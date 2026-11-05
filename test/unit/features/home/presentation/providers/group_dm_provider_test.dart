import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockChatWebsocketService extends Mock implements ChatWebsocketService {}

void main() {
  const member1 = TeamMember(
    id: 'm1',
    email: 'test@example.com',
    role: 'member',
    dateJoined: '2026-01-01',
    status: TeamMemberStatus.active,
  );

  const member2 = TeamMember(
    id: 'm2',
    email: 'test2@example.com',
    role: 'member',
    dateJoined: '2026-01-01',
    status: TeamMemberStatus.active,
  );

  group('GroupDmNotifier websocket lifecycle and subscription cleanup', () {
    late MockChatWebsocketService mockWs;
    late StreamController<ChatWebsocketMessage> wsController;
    late ProviderContainer container;

    setUp(() {
      mockWs = MockChatWebsocketService();
      wsController = StreamController<ChatWebsocketMessage>.broadcast();
      when(() => mockWs.messageStream).thenAnswer((_) => wsController.stream);
      when(() => mockWs.connect(any())).thenReturn(null);

      container = ProviderContainer(
        overrides: [chatWebsocketProvider.overrideWithValue(mockWs)],
      );
    });

    tearDown(() {
      container.dispose();
      wsController.close();
    });

    test(
      'initializes with empty state and listens to message stream',
      () async {
        final initial = container.read(groupDmProvider);
        expect(initial, isEmpty);

        // Create a group DM
        final result = await container
            .read(groupDmProvider.notifier)
            .createGroupDm([member1]);
        expect(result, isA<Success<GroupDM>>());
        final groupId = (result as Success<GroupDM>).value.id;

        // Emit incoming message
        wsController.add(
          ChatWebsocketMessage(
            groupDmId: groupId,
            text: 'Hello from websocket',
            authorName: 'Test Author',
            timestamp: DateTime.now(),
          ),
        );

        // Wait for stream event to propagate
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final groups = container.read(groupDmProvider);
        expect(groups.length, 1);
        expect(groups.first.messages, contains('Hello from websocket'));
        expect(groups.first.unreadCount, 1);
      },
    );

    test(
      'cancels websocket subscription when provider container is disposed',
      () async {
        // Initialize listener
        container.read(groupDmProvider);

        // Dispose container
        container.dispose();

        // Emitting on websocket stream after disposal must not throw StateError
        expect(
          () => wsController.add(
            ChatWebsocketMessage(
              groupDmId: 'g1',
              text: 'Message after dispose',
              authorName: 'Test Author',
              timestamp: DateTime.now(),
            ),
          ),
          returnsNormally,
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
    );

    test(
      'rebuilding notifier does not create duplicate subscriptions',
      () async {
        // Create a group DM
        await container.read(groupDmProvider.notifier).createGroupDm([member1]);

        // Invalidate and re-read to trigger rebuild
        container.invalidate(groupDmProvider);
        final reloaded = container.read(groupDmProvider);
        expect(reloaded, isEmpty);

        // Create new group on the new instance
        final newResult = await container
            .read(groupDmProvider.notifier)
            .createGroupDm([member2]);
        final newGroupId = (newResult as Success<GroupDM>).value.id;

        // Emit one message to new group
        wsController.add(
          ChatWebsocketMessage(
            groupDmId: newGroupId,
            text: 'Single event test',
            authorName: 'Test Author',
            timestamp: DateTime.now(),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final groups = container.read(groupDmProvider);
        final group = groups.firstWhere((g) => g.id == newGroupId);
        expect(group.messages.where((m) => m == 'Single event test').length, 1);
        expect(group.unreadCount, 1);
      },
    );
  });
}
