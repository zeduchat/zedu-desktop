import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';
import '../../fakes/buzz_call_fakes.dart';

void main() {
  late FakeBuzzCallRepository repo;
  late FakeBuzzCallService media;
  late FakeCallSignaling signaling;
  late ProviderContainer container;

  ProviderContainer build({Duration ringTimeout = kBuzzRingTimeout}) {
    final c = ProviderContainer(
      overrides: [
        buzzRepositoryProvider.overrideWithValue(repo),
        buzzCallServiceProvider.overrideWithValue(media),
        callSignalingProvider.overrideWithValue(signaling),
        callRingtoneProvider.overrideWithValue(FakeRingtone()),
        authNotifierProvider.overrideWith(FakeSignedInAuthNotifier.new),
        activeCallProvider.overrideWith(
          (ref) => ActiveCallNotifier(ref, ringTimeout: ringTimeout),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  ActiveCallNotifier calls() => container.read(activeCallProvider);
  ActiveCallState state() => calls().state;

  Future<void> settle() => pumpEventQueue();

  Future<void> startCall() => calls().initiateCall(
    remoteUserId: 'bob',
    remoteUserName: 'Bob',
    channelId: 'dm-1',
  );

  /// Bob joins the media channel and is identified as `bob`.
  Future<void> bobJoins() async {
    media
      ..emit(const BuzzRemoteIdentified(7, 'bob'))
      ..emit(const BuzzRemoteJoined(BuzzChannel.call, 7));
    await settle();
  }

  Future<void> ringIn({String buzzId = kTestBuzzId}) async {
    calls().receiveIncomingCall(
      buzzId: buzzId,
      remoteUserId: 'bob',
      remoteUserName: 'Bob',
      channelId: 'dm-1',
    );
    await settle();
  }

  setUp(() {
    repo = FakeBuzzCallRepository();
    media = FakeBuzzCallService();
    signaling = FakeCallSignaling();
    container = build();
  });

  group('outgoing call', () {
    test('creates the call, joins with the buzz code and rings', () async {
      await startCall();
      await settle();

      expect(state().status, CallStatus.calling);
      expect(state().isOutgoing, isTrue);
      expect(state().buzzId, kTestBuzzId);
      expect(repo.calls, [
        'direct-call:dm-1',
        'join:$kTestBuzzCode',
        // After joining the call channel: the screen-share channel's token.
      ]);
      expect(media.calls, [
        'init:app-id',
        'join:$kTestBuzzId:$kTestUserId:rtc-token:video=false',
      ]);
    });

    test('turns active when the other person joins the media', () async {
      await startCall();
      await bobJoins();

      expect(state().status, CallStatus.active);
      expect(state().connectedAt, isNotNull);
      expect(state().participants.single.name, 'Bob');
      expect(state().participants.single.avatarUrl, 'https://img/bob.png');
    });

    test('joins the screen channel as screen-<user id> once joined', () async {
      await startCall();
      media.emit(const BuzzJoined(BuzzChannel.call));
      await settle();

      expect(repo.calls, contains('token:$kTestBuzzId:screen-$kTestUserId'));
      expect(
        media.calls,
        contains(
          'join-screen:screen-$kTestBuzzId:screen-$kTestUserId:'
          'screen-token',
        ),
      );
      // The caller keeps ringing until the other person joins.
      expect(state().status, CallStatus.calling);
    });

    test('nobody answering in time cancels the call as no answer', () async {
      container = build(ringTimeout: const Duration(milliseconds: 30));
      await startCall();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await settle();

      expect(state().status, CallStatus.ended);
      expect(state().endReason, CallEndReason.noAnswer);
      expect(repo.calls, contains('respond:$kTestBuzzId:cancel'));
      expect(media.calls, contains('dispose'));
    });

    test('the other person declining ends it', () async {
      await startCall();
      signaling.emit(
        const CallResponseSignal(buzzId: kTestBuzzId, joinStatus: 'decline'),
      );
      await settle();

      expect(state().status, CallStatus.ended);
      expect(state().endReason, CallEndReason.remoteDeclined);
      expect(media.calls, contains('dispose'));
    });

    test('a response for another call is ignored', () async {
      await startCall();
      signaling.emit(
        const CallResponseSignal(buzzId: 'other', joinStatus: 'decline'),
      );
      await settle();

      expect(state().status, CallStatus.calling);
    });

    test('cancelling stops the ringing on the server', () async {
      await startCall();
      await calls().cancelCall();

      expect(state().status, CallStatus.ended);
      expect(state().endReason, CallEndReason.canceled);
      expect(repo.calls.last, 'respond:$kTestBuzzId:cancel');
      expect(media.calls, contains('dispose'));
    });

    test('cancelling while the call is being created still cancels it '
        'on the server, and never joins', () async {
      repo.holdStart = Completer<void>();
      final starting = startCall();
      await settle();
      expect(state().status, CallStatus.calling);

      await calls().cancelCall();
      repo.holdStart!.complete();
      await starting;
      await settle();

      expect(state().endReason, CallEndReason.canceled);
      expect(repo.calls, contains('respond:$kTestBuzzId:cancel'));
      expect(repo.calls, isNot(contains('join:$kTestBuzzCode')));
      expect(media.calls, isEmpty);
    });

    test('a failed create ends it with a message and no media', () async {
      repo.startResult = const Failure(
        ApiFailure(message: 'boom', kind: ApiFailureKind.server),
      );
      await startCall();

      expect(state().status, CallStatus.ended);
      expect(state().endReason, CallEndReason.failed);
      expect(state().errorMessage, isNotEmpty);
      expect(media.calls, isEmpty);
    });

    test('a failed join cancels the created call', () async {
      repo.joinResult = const Failure(
        ApiFailure(message: 'boom', kind: ApiFailureKind.server),
      );
      await startCall();
      await settle();

      expect(state().endReason, CallEndReason.failed);
      expect(repo.calls, contains('respond:$kTestBuzzId:cancel'));
    });

    test(
      'a media join failure ends the call and releases the engine',
      () async {
        media.failJoin = true;
        await startCall();
        await settle();

        expect(state().endReason, CallEndReason.failed);
        expect(media.calls, contains('dispose'));
        expect(repo.calls, contains('respond:$kTestBuzzId:cancel'));
      },
    );

    test(
      'on an unsupported platform it ends at once, calling nothing',
      () async {
        media.isSupported = false;
        await startCall();

        expect(state().status, CallStatus.ended);
        expect(state().endReason, CallEndReason.unsupported);
        expect(state().errorMessage, contains('Linux'));
        expect(repo.calls, isEmpty);
      },
    );

    test('a second call is not started while one is ringing', () async {
      await startCall();
      await startCall();

      expect(
        repo.calls.where((c) => c.startsWith('direct-call')),
        hasLength(1),
      );
    });
  });

  group('incoming call', () {
    test('rings, then accepting answers and joins', () async {
      await ringIn();
      expect(state().status, CallStatus.incoming);

      final accepting = calls().acceptCall();
      expect(state().status, CallStatus.connecting);
      await accepting;
      await settle();

      expect(repo.calls, [
        'respond:$kTestBuzzId:accept',
        'join:$kTestBuzzCode',
      ]);
      expect(state().status, CallStatus.connecting);

      media.emit(const BuzzJoined(BuzzChannel.call));
      await settle();
      expect(state().status, CallStatus.active);
      expect(state().connectedAt, isNotNull);
    });

    test('declining tells the server', () async {
      await ringIn();
      await calls().declineCall();

      expect(state().status, CallStatus.ended);
      expect(state().endReason, CallEndReason.declined);
      expect(repo.calls, ['respond:$kTestBuzzId:decline']);
    });

    test(
      'not answering in time reports a timeout and counts as missed',
      () async {
        container = build(ringTimeout: const Duration(milliseconds: 30));
        await ringIn();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await settle();

        expect(state().endReason, CallEndReason.missed);
        expect(repo.calls, ['respond:$kTestBuzzId:timeout']);
      },
    );

    test('the caller cancelling hides it', () async {
      await ringIn();
      signaling.emit(const CallCanceledSignal(buzzId: kTestBuzzId));
      await settle();

      expect(state().status, CallStatus.ended);
      expect(state().endReason, CallEndReason.remoteCanceled);
    });

    test('arrives from the server signal; your own call is ignored', () async {
      signaling.emit(
        const IncomingCallSignal(
          buzzId: 'b-self',
          callerId: kTestUserId,
          callerName: 'Ada',
          channelId: 'dm-1',
        ),
      );
      await settle();
      expect(state().status, CallStatus.none);

      signaling.emit(
        const IncomingCallSignal(
          buzzId: kTestBuzzId,
          callerId: 'bob',
          callerName: 'Bob',
          channelId: 'dm-1',
          avatarUrl: 'https://img/bob.png',
        ),
      );
      await settle();
      expect(state().status, CallStatus.incoming);
      expect(state().remoteUserName, 'Bob');
      expect(state().remoteAvatarUrl, 'https://img/bob.png');
    });

    test(
      'still rings for a call that arrives after an outgoing one ended',
      () async {
        await startCall();
        signaling.emit(
          const CallResponseSignal(buzzId: kTestBuzzId, joinStatus: 'decline'),
        );
        await settle();
        expect(state().status, CallStatus.ended);

        signaling.emit(
          const IncomingCallSignal(
            buzzId: 'b-next',
            callerId: 'carol',
            callerName: 'Carol',
            channelId: 'dm-2',
          ),
        );
        await settle();
        expect(state().status, CallStatus.incoming);
        expect(state().buzzId, 'b-next');
        expect(state().remoteUserName, 'Carol');
      },
    );

    test('a second call while busy is declined and changes nothing', () async {
      await ringIn();
      await ringIn(buzzId: 'buzz-2');

      expect(state().buzzId, kTestBuzzId);
      expect(repo.calls, ['respond:buzz-2:decline']);
    });

    test('a failed answer ends it', () async {
      repo.respondResult = const Failure(
        ApiFailure(message: 'gone', kind: ApiFailureKind.server),
      );
      await ringIn();
      await calls().acceptCall();

      expect(state().endReason, CallEndReason.failed);
      expect(media.calls, isEmpty);
    });
  });

  group('leaving and ending', () {
    Future<void> activeCall() async {
      await startCall();
      await bobJoins();
      expect(state().status, CallStatus.active);
    }

    test('leave with someone still in the call only leaves', () async {
      await activeCall();
      await calls().leaveCall();

      expect(state().endReason, CallEndReason.left);
      expect(repo.calls, contains('leave:$kTestBuzzId'));
      expect(repo.calls, isNot(contains('end:$kTestBuzzId')));
      expect(media.calls, contains('dispose'));
    });

    test('leaving as the last person in the call also ends it', () async {
      // Answered, but nobody else is in the media channel any more.
      await ringIn();
      await calls().acceptCall();
      media.emit(const BuzzJoined(BuzzChannel.call));
      await settle();
      expect(state().status, CallStatus.active);

      await calls().leaveCall();
      expect(
        repo.calls,
        containsAllInOrder(['leave:$kTestBuzzId', 'end:$kTestBuzzId']),
      );
    });

    test('someone unknown leaving does not end the call', () async {
      await activeCall();
      media.emit(const BuzzRemoteLeft(BuzzChannel.call, 99));
      await settle();

      expect(state().status, CallStatus.active);
    });

    test('ending for everyone calls end, not leave', () async {
      await activeCall();
      await calls().endCallForEveryone();

      expect(state().endReason, CallEndReason.endedForAll);
      expect(repo.calls, contains('end:$kTestBuzzId'));
      expect(repo.calls, isNot(contains('leave:$kTestBuzzId')));
      expect(media.calls, contains('dispose'));
    });

    test('the other person leaving ends the call here too', () async {
      await activeCall();
      media.emit(const BuzzRemoteLeft(BuzzChannel.call, 7));
      await settle();

      expect(state().status, CallStatus.ended);
      expect(state().endReason, CallEndReason.remoteLeft);
      expect(
        repo.calls,
        containsAllInOrder(['leave:$kTestBuzzId', 'end:$kTestBuzzId']),
      );
      expect(media.calls, contains('dispose'));
    });

    test('the hang-up button leaves an active call', () async {
      await activeCall();
      await calls().endCall();

      expect(state().endReason, CallEndReason.left);
    });

    test('the hang-up button declines an incoming call', () async {
      await ringIn();
      await calls().endCall();

      expect(state().endReason, CallEndReason.declined);
    });
  });

  group('connection', () {
    Future<void> activeCall() async {
      await startCall();
      await bobJoins();
    }

    test('reconnecting and recovering', () async {
      await activeCall();
      media.emit(
        const BuzzLinkChanged(BuzzChannel.call, BuzzLinkState.reconnecting),
      );
      await settle();
      expect(state().status, CallStatus.reconnecting);

      media.emit(
        const BuzzLinkChanged(BuzzChannel.call, BuzzLinkState.connected),
      );
      await settle();
      expect(state().status, CallStatus.active);
    });

    test('the link failing ends the call and leaves', () async {
      await activeCall();
      media.emit(const BuzzLinkChanged(BuzzChannel.call, BuzzLinkState.failed));
      await settle();

      expect(state().endReason, CallEndReason.failed);
      expect(repo.calls, contains('leave:$kTestBuzzId'));
      expect(media.calls, contains('dispose'));
    });

    test('the screen channel reconnecting does not affect the call', () async {
      await activeCall();
      media.emit(
        const BuzzLinkChanged(BuzzChannel.screen, BuzzLinkState.reconnecting),
      );
      await settle();
      expect(state().status, CallStatus.active);
    });

    test('network quality and the active speaker are tracked', () async {
      await activeCall();
      media
        ..emit(const BuzzQualityChanged(BuzzNetworkQuality.poor))
        ..emit(const BuzzActiveSpeaker(7));
      await settle();
      expect(state().networkQuality, BuzzNetworkQuality.poor);
      expect(state().activeSpeakerId, 'bob');

      media.emit(const BuzzActiveSpeaker(0));
      await settle();
      expect(state().activeSpeakerId, kTestUserId);
    });

    test('a remote camera turning on shows on their tile', () async {
      await activeCall();
      media.emit(const BuzzRemoteVideoChanged(BuzzChannel.call, 7, true));
      await settle();

      expect(state().participants.single.hasVideo, isTrue);
    });
  });

  group('microphone and camera', () {
    Future<void> activeCall() async {
      await startCall();
      await bobJoins();
    }

    test('toggles control the engine', () async {
      await activeCall();
      await calls().toggleMicrophone();
      await calls().toggleCamera();

      expect(state().isMicMuted, isTrue);
      expect(state().isCameraOn, isTrue);
      expect(media.calls, containsAll(['mic-muted:true', 'camera:true']));
    });

    test('a failure puts the button back', () async {
      await activeCall();
      media.failMicrophone = true;
      await calls().toggleMicrophone();

      expect(state().isMicMuted, isFalse);
    });

    test('nothing happens outside a call', () async {
      await calls().toggleMicrophone();

      expect(state().isMicMuted, isFalse);
      expect(media.calls, isEmpty);
    });
  });

  group('screen sharing', () {
    Future<void> activeCall() async {
      await startCall();
      await bobJoins();
    }

    test('lists sources, starts and stops sharing', () async {
      await activeCall();
      final sources = await calls().screenSources();
      expect(sources, hasLength(2));

      final started = await calls().startScreenShare(sources.last);
      expect(started, isTrue);
      expect(state().isSharingScreen, isTrue);
      expect(state().sharedSourceName, 'Slides');
      expect(media.calls, contains('share:42'));

      await calls().stopScreenShare();
      expect(state().isSharingScreen, isFalse);
      expect(state().sharedSourceName, isNull);
      expect(media.calls, contains('stop-share'));
    });

    test(
      'a failed start explains itself and does not claim to share',
      () async {
        await activeCall();
        media.failScreenShare = true;
        final started = await calls().startScreenShare(media.sources.first);

        expect(started, isFalse);
        expect(state().isSharingScreen, isFalse);
        expect(state().errorMessage, isNotEmpty);
      },
    );

    test('cannot share before the call is active', () async {
      await startCall();
      final started = await calls().startScreenShare(media.sources.first);

      expect(started, isFalse);
      expect(await calls().screenSources(), isEmpty);
    });

    test("someone else's share is picked up from the screen channel", () async {
      await activeCall();
      media
        ..emit(const BuzzRemoteIdentified(70, 'screen-bob'))
        ..emit(const BuzzRemoteVideoChanged(BuzzChannel.screen, 70, true));
      await settle();
      expect(state().remoteScreenSharerId, 'bob');

      media.emit(const BuzzRemoteVideoChanged(BuzzChannel.screen, 70, false));
      await settle();
      expect(state().remoteScreenSharerId, isNull);
    });

    test("someone else's share is rendered from their screen uid", () async {
      await activeCall();
      expect(calls().remoteScreenView(), isNull);

      media
        ..emit(const BuzzRemoteIdentified(70, 'screen-bob'))
        ..emit(const BuzzRemoteVideoChanged(BuzzChannel.screen, 70, true));
      await settle();

      final view = calls().remoteScreenView();
      expect(view?.key, const ValueKey('remote-screen-70'));

      media.emit(const BuzzRemoteVideoChanged(BuzzChannel.screen, 70, false));
      await settle();
      expect(calls().remoteScreenView(), isNull);
    });

    test('leaving while sharing releases the engine', () async {
      await activeCall();
      await calls().startScreenShare(media.sources.first);
      await calls().leaveCall();

      expect(state().isSharingScreen, isFalse);
      expect(media.calls, contains('dispose'));
    });

    test(
      'your own share on the screen channel is not shown as remote',
      () async {
        await activeCall();
        media
          ..emit(const BuzzRemoteIdentified(71, 'screen-$kTestUserId'))
          ..emit(const BuzzRemoteVideoChanged(BuzzChannel.screen, 71, true));
        await settle();

        expect(state().remoteScreenSharerId, isNull);
      },
    );
  });

  group('reactions', () {
    test('are sent to the active call', () async {
      await startCall();
      await bobJoins();

      expect(await calls().sendReaction('👍'), isTrue);
      expect(repo.calls, contains('reaction:$kTestBuzzId:👍'));
    });

    test('are not sent outside a call', () async {
      expect(await calls().sendReaction('👍'), isFalse);
    });
  });

  test('disposing mid-call releases the engine without throwing', () async {
    await startCall();
    await bobJoins();

    calls().dispose();
    await settle();

    expect(media.calls, contains('dispose'));
  });

  group('notifyListeners (#2594)', () {
    test(
      'one override both rings a coming call and stays silent after dispose',
      () async {
        final ringtone = _MergeGuardRingtone();
        final container = ProviderContainer(
          overrides: [
            callRingtoneProvider.overrideWithValue(ringtone),
            buzzRepositoryProvider.overrideWithValue(FakeBuzzCallRepository()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(activeCallProvider);
        var notifications = 0;
        notifier.addListener(() => notifications++);

        notifier.receiveIncomingCall(
          buzzId: 'buzz-1',
          remoteUserId: 'u-1',
          remoteUserName: 'Ada',
          channelId: 'c-1',
        );
        expect(ringtone.calls, ['start']);
        expect(notifications, 1);

        // A second update while still ringing: notified, and it does not re-ring.
        notifier.setFullPage(true);
        expect(ringtone.calls, ['start']);
        expect(notifications, 2);

        notifier.dispose();
        notifier.setFullPage(false);
        expect(notifications, 2);
        // dispose() stops the ring it holds; the update after it adds nothing.
        expect(ringtone.calls, ['start', 'stop']);
      },
    );
  });
}

class _MergeGuardRingtone implements CallRingtone {
  final calls = <String>[];

  @override
  Future<void> start() async => calls.add('start');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> dispose() async => calls.add('dispose');
}
