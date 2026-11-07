import 'dart:async';

import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockChannelRepository extends Mock implements ChannelRepository {}

class FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Test org', avatar: ''),
  );
}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'user-1',
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      phone: '',
      username: 'testuser',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'test-org',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

Channel _channel(String name) => Channel(
  id: 'channel-$name',
  name: name,
  description: '',
  organisationId: 'org-1',
  ownerId: 'user-1',
);

void main() {
  group('ChannelNotifier.createChannel', () {
    late MockChannelRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = MockChannelRepository();
      when(
        () => repository.fetchChannels(any()),
      ).thenAnswer((_) async => Success<List<Channel>>([_channel('general')]));

      container = ProviderContainer(
        overrides: [
          channelRepositoryProvider.overrideWithValue(repository),
          workspaceProvider.overrideWith(FakeWorkspaceNotifier.new),
          authNotifierProvider.overrideWith(FakeAuthNotifier.new),
        ],
      );
      addTearDown(container.dispose);
    });

    void stubCreateChannel(Result<Channel> result) {
      when(
        () => repository.createChannel(
          name: any(named: 'name'),
          description: any(named: 'description'),
          orgId: any(named: 'orgId'),
          username: any(named: 'username'),
          isPrivate: any(named: 'isPrivate'),
          topic: any(named: 'topic'),
        ),
      ).thenAnswer((_) async => result);
    }

    // Reads the notifier and waits for the first channel fetch to finish.
    Future<ChannelNotifier> loadNotifier() async {
      await container.read(channelProvider.future);
      return container.read(channelProvider.notifier);
    }

    test('adds the new channel to the list and returns the channel', () async {
      stubCreateChannel(Success<Channel>(_channel('team-heron')));
      final notifier = await loadNotifier();

      final result = await notifier.createChannel(
        name: 'team-heron',
        description: '',
        isPrivate: false,
      );

      final state = container.read(channelProvider);
      expect(result, isA<Success<Channel>>());
      expect(state.requireValue.map((c) => c.name), ['general', 'team-heron']);
      expect(state.isLoading, isFalse);
      expect(state.hasError, isFalse);
    });

    test(
      'keeps every channel when the server sends channels without ids',
      () async {
        Channel noId(String name) => Channel(
          id: '',
          name: name,
          description: '',
          organisationId: 'org-1',
          ownerId: 'user-1',
        );
        when(() => repository.fetchChannels(any())).thenAnswer(
          (_) async =>
              Success<List<Channel>>([noId('general'), noId('team-heron')]),
        );
        stubCreateChannel(Success<Channel>(noId('plan')));
        final notifier = await loadNotifier();

        final result = await notifier.createChannel(
          name: 'plan',
          description: '',
          isPrivate: false,
        );

        expect(result, isA<Success<Channel>>());
        expect(
          container.read(channelProvider).requireValue.map((c) => c.name),
          ['general', 'team-heron', 'plan'],
        );
      },
    );

    test(
      'returns the server message and leaves the list state alone',
      () async {
        stubCreateChannel(
          const Failure<Channel>(
            ApiFailure(message: 'Channel name already exists'),
          ),
        );
        final notifier = await loadNotifier();

        final result = await notifier.createChannel(
          name: 'general',
          description: '',
          isPrivate: false,
        );

        final state = container.read(channelProvider);
        expect(
          (result as Failure<Channel>).error.message,
          'Channel name already exists',
        );
        expect(state.requireValue.map((c) => c.name), ['general']);
        expect(state.isLoading, isFalse);
        // A create error must not look like a failed channel load.
        expect(state.hasError, isFalse);
      },
    );

    test('ignores a second create while one is still running', () async {
      final pending = Completer<Result<Channel>>();
      when(
        () => repository.createChannel(
          name: any(named: 'name'),
          description: any(named: 'description'),
          orgId: any(named: 'orgId'),
          username: any(named: 'username'),
          isPrivate: any(named: 'isPrivate'),
          topic: any(named: 'topic'),
        ),
      ).thenAnswer((_) => pending.future);
      final notifier = await loadNotifier();

      final first = notifier.createChannel(
        name: 'team-heron',
        description: '',
        isPrivate: false,
      );
      final second = await notifier.createChannel(
        name: 'team-heron-2',
        description: '',
        isPrivate: false,
      );
      pending.complete(Success<Channel>(_channel('team-heron')));

      expect(second, isA<Failure<Channel>>());
      expect(await first, isA<Success<Channel>>());
      verify(
        () => repository.createChannel(
          name: any(named: 'name'),
          description: any(named: 'description'),
          orgId: any(named: 'orgId'),
          username: any(named: 'username'),
          isPrivate: any(named: 'isPrivate'),
          topic: any(named: 'topic'),
        ),
      ).called(1);
    });
  });

  group('ChannelNotifier.leaveChannel', () {
    late MockChannelRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = MockChannelRepository();
      when(() => repository.fetchChannels(any())).thenAnswer(
        (_) async =>
            Success<List<Channel>>([_channel('general'), _channel('random')]),
      );

      container = ProviderContainer(
        overrides: [
          channelRepositoryProvider.overrideWithValue(repository),
          workspaceProvider.overrideWith(FakeWorkspaceNotifier.new),
          authNotifierProvider.overrideWith(FakeAuthNotifier.new),
        ],
      );
      addTearDown(container.dispose);
    });

    test(
      'calls the repository and removes the channel from the list',
      () async {
        when(
          () => repository.leaveChannel(any()),
        ).thenAnswer((_) async => const Success<void>(null));
        await container.read(channelProvider.future);

        final result = await container
            .read(channelProvider.notifier)
            .leaveChannel('channel-random');

        expect(result, isA<Success<void>>());
        verify(() => repository.leaveChannel('channel-random')).called(1);
        expect(
          container.read(channelProvider).requireValue.map((c) => c.name),
          ['general'],
        );
      },
    );

    test('keeps the list and returns the error when leaving fails', () async {
      when(() => repository.leaveChannel(any())).thenAnswer(
        (_) async => const Failure<void>(ApiFailure(message: 'Not allowed')),
      );
      await container.read(channelProvider.future);

      final result = await container
          .read(channelProvider.notifier)
          .leaveChannel('channel-random');

      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).error.message, 'Not allowed');
      final state = container.read(channelProvider);
      expect(state.requireValue.map((c) => c.name), ['general', 'random']);
      expect(state.hasError, isFalse);
    });
  });

  group('ChannelNotifier.archiveChannel', () {
    late MockChannelRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = MockChannelRepository();
      when(() => repository.fetchChannels(any())).thenAnswer(
        (_) async =>
            Success<List<Channel>>([_channel('general'), _channel('random')]),
      );
      when(
        () => repository.fetchArchivedChannels(any()),
      ).thenAnswer((_) async => const Success<List<Channel>>([]));

      container = ProviderContainer(
        overrides: [
          channelRepositoryProvider.overrideWithValue(repository),
          workspaceProvider.overrideWith(FakeWorkspaceNotifier.new),
          authNotifierProvider.overrideWith(FakeAuthNotifier.new),
        ],
      );
      addTearDown(container.dispose);
    });

    test('archiving sends the flag and removes the channel', () async {
      when(
        () => repository.archiveChannel(any(), any()),
      ).thenAnswer((_) async => const Success<void>(null));
      await container.read(channelProvider.future);

      final result = await container
          .read(channelProvider.notifier)
          .archiveChannel(_channel('random'), archived: true);

      expect(result, isA<Success<void>>());
      verify(() => repository.archiveChannel('channel-random', true)).called(1);
      expect(container.read(channelProvider).requireValue.map((c) => c.name), [
        'general',
      ]);
    });

    test('unarchiving brings the channel back, not archived', () async {
      when(
        () => repository.archiveChannel(any(), any()),
      ).thenAnswer((_) async => const Success<void>(null));
      await container.read(channelProvider.future);

      await container
          .read(channelProvider.notifier)
          .archiveChannel(
            _channel('old').copyWith(archived: true),
            archived: false,
          );

      verify(() => repository.archiveChannel('channel-old', false)).called(1);
      final channels = container.read(channelProvider).requireValue;
      expect(channels.map((c) => c.name), ['general', 'random', 'old']);
      expect(channels.last.archived, isFalse);
    });

    test('a success reloads the archived list', () async {
      when(
        () => repository.archiveChannel(any(), any()),
      ).thenAnswer((_) async => const Success<void>(null));
      await container.read(channelProvider.future);
      await container.read(archivedChannelsProvider.future);
      verify(() => repository.fetchArchivedChannels('org-1')).called(1);

      await container
          .read(channelProvider.notifier)
          .archiveChannel(_channel('random'), archived: true);
      await container.read(archivedChannelsProvider.future);

      verify(() => repository.fetchArchivedChannels('org-1')).called(1);
    });

    test('a failure keeps the list and returns the error', () async {
      when(() => repository.archiveChannel(any(), any())).thenAnswer(
        (_) async => const Failure<void>(
          ApiFailure(message: 'Forbidden', kind: ApiFailureKind.forbidden),
        ),
      );
      await container.read(channelProvider.future);

      final result = await container
          .read(channelProvider.notifier)
          .archiveChannel(_channel('random'), archived: true);

      expect(result, isA<Failure<void>>());
      expect(container.read(channelProvider).requireValue.map((c) => c.name), [
        'general',
        'random',
      ]);
    });
  });

  group('ChannelNotifier.toggleStar (Ziki #2628)', () {
    late MockChannelRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = MockChannelRepository();
      when(() => repository.fetchChannels(any())).thenAnswer(
        (_) async =>
            Success<List<Channel>>([_channel('general'), _channel('random')]),
      );
      container = ProviderContainer(
        overrides: [
          channelRepositoryProvider.overrideWithValue(repository),
          workspaceProvider.overrideWith(FakeWorkspaceNotifier.new),
          authNotifierProvider.overrideWith(FakeAuthNotifier.new),
        ],
      );
      addTearDown(container.dispose);
    });

    bool starredOf(String name) => container
        .read(channelProvider)
        .requireValue
        .firstWhere((c) => c.name == name)
        .isStarred;

    test('stores the star state the server answers with', () async {
      when(
        () => repository.toggleStarChannel(
          orgId: 'org-1',
          channelId: 'channel-general',
        ),
      ).thenAnswer((_) async => const Success(true));
      await container.read(channelProvider.future);

      final result = await container
          .read(channelProvider.notifier)
          .toggleStar('channel-general');

      expect(result, isA<Success<bool>>());
      expect(starredOf('general'), isTrue);
      expect(starredOf('random'), isFalse);
    });

    test('a failure leaves the star as it was', () async {
      when(
        () => repository.toggleStarChannel(
          orgId: any(named: 'orgId'),
          channelId: any(named: 'channelId'),
        ),
      ).thenAnswer(
        (_) async => const Failure<bool>(ApiFailure(message: 'Server error')),
      );
      await container.read(channelProvider.future);

      final result = await container
          .read(channelProvider.notifier)
          .toggleStar('channel-general');

      expect(result, isA<Failure<bool>>());
      expect(starredOf('general'), isFalse);
    });

    test('a second toggle while one is running is refused', () async {
      final gate = Completer<Result<bool>>();
      when(
        () => repository.toggleStarChannel(
          orgId: any(named: 'orgId'),
          channelId: any(named: 'channelId'),
        ),
      ).thenAnswer((_) => gate.future);
      await container.read(channelProvider.future);
      final notifier = container.read(channelProvider.notifier);

      final first = notifier.toggleStar('channel-general');
      final second = await notifier.toggleStar('channel-general');
      gate.complete(const Success(true));
      await first;

      expect(second, isA<Failure<bool>>());
      verify(
        () => repository.toggleStarChannel(
          orgId: 'org-1',
          channelId: 'channel-general',
        ),
      ).called(1);
      expect(starredOf('general'), isTrue);
    });
  });

  test('Channel.fromJson reads is_starred', () {
    final json = {'channels_id': 'c1', 'name': 'general', 'is_starred': true};
    expect(Channel.fromJson(json).isStarred, isTrue);
    expect(
      Channel.fromJson({...json}..remove('is_starred')).isStarred,
      isFalse,
    );
  });
}
