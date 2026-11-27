import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

const kTestUserId = 'me';
const kTestBuzzId = 'buzz-1';
const kTestBuzzCode = 'CODE1';

BuzzSession testSession({String buzzId = kTestBuzzId}) => BuzzSession(
  buzzId: buzzId,
  buzzCode: kTestBuzzCode,
  hostId: kTestUserId,
  agora: BuzzAgoraCredentials(
    token: 'rtc-token',
    appId: 'app-id',
    channelName: buzzId,
    uid: kTestUserId,
  ),
  participants: const [
    BuzzCallParticipant(
      userId: 'bob',
      username: 'Bob',
      avatarUrl: 'https://img/bob.png',
    ),
  ],
);

/// Records every call and answers from configurable results.
class FakeBuzzCallRepository implements BuzzCallRepository {
  final calls = <String>[];

  Result<DirectCall> startResult = const Success(
    DirectCall(buzzId: kTestBuzzId, buzzCode: kTestBuzzCode),
  );
  Result<BuzzSession> joinResult = Success(testSession());
  Result<DirectCall> respondResult = const Success(
    DirectCall(buzzId: kTestBuzzId, buzzCode: kTestBuzzCode),
  );
  Result<BuzzAgoraCredentials> tokenResult = const Success(
    BuzzAgoraCredentials(
      token: 'screen-token',
      appId: 'app-id',
      channelName: 'screen-$kTestBuzzId',
      uid: 'screen-$kTestUserId',
    ),
  );

  /// When set, [startDirectCall] waits for it.
  Completer<void>? holdStart;

  @override
  Future<Result<DirectCall>> startDirectCall(String channelId) async {
    calls.add('direct-call:$channelId');
    if (holdStart != null) await holdStart!.future;
    return startResult;
  }

  @override
  Future<Result<BuzzSession>> join(String buzzIdOrCode) async {
    calls.add('join:$buzzIdOrCode');
    return joinResult;
  }

  @override
  Future<Result<DirectCall>> respond(
    String buzzId,
    BuzzCallResponse action,
  ) async {
    calls.add('respond:$buzzId:${action.apiValue}');
    return respondResult;
  }

  @override
  Future<Result<BuzzAgoraCredentials>> token({
    required String buzzId,
    required String uid,
  }) async {
    calls.add('token:$buzzId:$uid');
    return tokenResult;
  }

  @override
  Future<Result<void>> leave(String buzzId) async {
    calls.add('leave:$buzzId');
    return const Success(null);
  }

  @override
  Future<Result<void>> end(String buzzId) async {
    calls.add('end:$buzzId');
    return const Success(null);
  }

  @override
  Future<Result<void>> sendReaction(String buzzId, String emoji) async {
    calls.add('reaction:$buzzId:$emoji');
    return const Success(null);
  }

  @override
  Future<Result<void>> muteParticipants(String buzzId) async {
    calls.add('mute-participants:$buzzId');
    return const Success(null);
  }

  @override
  Future<Result<Map<String, dynamic>>> metadata(String buzzId) async {
    calls.add('metadata:$buzzId');
    return const Success(<String, dynamic>{});
  }
}

/// A media engine that records calls and lets tests send its events.
class FakeBuzzCallService implements BuzzCallService {
  final calls = <String>[];
  final _events = StreamController<BuzzCallEvent>.broadcast();

  @override
  bool isSupported = true;

  bool failJoin = false;
  bool failScreenShare = false;
  bool failMicrophone = false;
  List<BuzzScreenSource> sources = const [
    BuzzScreenSource(id: 1, name: 'Main display', isScreen: true),
    BuzzScreenSource(id: 42, name: 'Slides', isScreen: false),
  ];

  void emit(BuzzCallEvent event) => _events.add(event);

  @override
  Stream<BuzzCallEvent> get events => _events.stream;

  @override
  Future<void> initialize(String appId) async => calls.add('init:$appId');

  @override
  Future<void> joinCall({
    required String token,
    required String channelId,
    required String userAccount,
    required bool withVideo,
  }) async {
    calls.add('join:$channelId:$userAccount:$token:video=$withVideo');
    if (failJoin) throw StateError('join failed');
  }

  @override
  Future<void> joinScreenChannel({
    required String token,
    required String channelId,
    required String userAccount,
  }) async => calls.add('join-screen:$channelId:$userAccount:$token');

  @override
  Future<void> setMicrophoneMuted(bool muted) async {
    calls.add('mic-muted:$muted');
    if (failMicrophone) throw StateError('no microphone');
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async =>
      calls.add('camera:$enabled');

  @override
  Future<List<BuzzScreenSource>> screenSources() async => sources;

  @override
  Future<void> startScreenShare(BuzzScreenSource source) async {
    calls.add('share:${source.id}');
    if (failScreenShare) throw StateError('permission denied');
  }

  @override
  Future<void> stopScreenShare() async => calls.add('stop-share');

  @override
  Widget? remoteScreenView(int remoteUid) =>
      SizedBox(key: ValueKey('remote-screen-$remoteUid'));

  @override
  Future<void> leave() async => calls.add('leave');

  @override
  Future<void> dispose() async => calls.add('dispose');
}

class FakeCallSignaling implements CallSignaling {
  final _signals = StreamController<CallSignal>.broadcast();

  void emit(CallSignal signal) => _signals.add(signal);

  @override
  Stream<CallSignal> get signals => _signals.stream;

  @override
  Future<void> dispose() => _signals.close();
}

class FakeSignedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: kTestUserId,
      firstName: 'Ada',
      lastName: 'Lovelace',
      email: 'ada@example.com',
      phone: '',
      username: 'ada',
      isVerified: true,
      isOnboarded: true,
      createdAt: DateTime(2026),
      currentOrg: 'org-1',
      currentOrganisationSlug: 'org',
      avatarUrl: '',
      defaultAvatarUrl: '',
    ),
  );
}

class FakeRingtone implements CallRingtone {
  final calls = <String>[];

  @override
  Future<void> start() async => calls.add('start');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> dispose() async => calls.add('dispose');
}
