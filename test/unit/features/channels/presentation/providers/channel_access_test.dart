import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockChannelRepository extends Mock implements ChannelRepository {}

class FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Test org', avatar: ''),
  );
}

Channel _channel(
  String name, {
  String id = '',
  bool hasAccess = true,
  bool archived = false,
}) => Channel(
  id: id.isNotEmpty ? id : 'c-$name',
  name: name,
  description: '',
  organisationId: 'org-1',
  ownerId: 'user-1',
  archived: archived,
  hasAccess: hasAccess,
);

void main() {
  group('Channel entity access parsing', () {
    test('parses boolean access flags', () {
      final withAccess = Channel.fromJson({
        'id': 'c1',
        'name': 'general',
        'access': true,
      });
      final withoutAccess = Channel.fromJson({
        'id': 'c2',
        'name': 'random',
        'access': false,
      });

      expect(withAccess.hasAccess, isTrue);
      expect(withoutAccess.hasAccess, isFalse);
    });

    test('parses string access flags', () {
      final withAccess = Channel.fromJson({
        'id': 'c1',
        'name': 'general',
        'access': 'true',
      });
      final withoutAccess = Channel.fromJson({
        'id': 'c2',
        'name': 'random',
        'access': 'false',
      });

      expect(withAccess.hasAccess, isTrue);
      expect(withoutAccess.hasAccess, isFalse);
    });

    test('defaults hasAccess to true when absent', () {
      final channel = Channel.fromJson({'id': 'c1', 'name': 'general'});

      expect(channel.hasAccess, isTrue);
    });
  });

  group('ChannelNotifier join and leave access state', () {
    late MockChannelRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = MockChannelRepository();
      when(() => repository.fetchChannels(any())).thenAnswer(
        (_) async => Success<List<Channel>>([
          _channel('general', id: 'c-general', hasAccess: true),
          _channel('left-channel', id: 'c-left', hasAccess: false),
        ]),
      );

      container = ProviderContainer(
        overrides: [
          channelRepositoryProvider.overrideWithValue(repository),
          workspaceProvider.overrideWith(FakeWorkspaceNotifier.new),
        ],
      );
      addTearDown(container.dispose);
    });

    test('leaveChannel keeps a public channel as not joined', () async {
      when(
        () => repository.leaveChannel('c-general'),
      ).thenAnswer((_) async => const Success(null));

      final channelsBefore = await container.read(channelProvider.future);
      expect(
        channelsBefore.firstWhere((c) => c.id == 'c-general').hasAccess,
        isTrue,
      );

      final result = await container
          .read(channelProvider.notifier)
          .leaveChannel('c-general');
      expect(result, isA<Success<void>>());

      final channelsAfter = container.read(channelProvider).value!;
      expect(
        channelsAfter.firstWhere((c) => c.id == 'c-general').hasAccess,
        isFalse,
      );
    });

    test('joinChannel marks the channel hasAccess as true in state', () async {
      when(
        () => repository.joinChannel('c-left'),
      ).thenAnswer((_) async => const Success(null));

      final channelsBefore = await container.read(channelProvider.future);
      expect(
        channelsBefore.firstWhere((c) => c.id == 'c-left').hasAccess,
        isFalse,
      );

      final result = await container
          .read(channelProvider.notifier)
          .joinChannel('c-left');
      expect(result, isA<Success<void>>());

      final channelsAfter = container.read(channelProvider).value!;
      expect(
        channelsAfter.firstWhere((c) => c.id == 'c-left').hasAccess,
        isTrue,
      );
    });
  });
}
