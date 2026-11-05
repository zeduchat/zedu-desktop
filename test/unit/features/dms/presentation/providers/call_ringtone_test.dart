import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class _FakeRingtone implements CallRingtone {
  final calls = <String>[];

  @override
  Future<void> start() async => calls.add('start');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> dispose() async => calls.add('dispose');
}

class _FakeBuzzRepository extends BuzzRepository {
  @override
  Future<bool> respondToInvitation(String buzzId, bool accept) async => true;
}

void main() {
  group('Incoming call ringtone (Ziki #2441)', () {
    late _FakeRingtone ringtone;
    late ProviderContainer container;

    setUp(() {
      ringtone = _FakeRingtone();
      container = ProviderContainer(
        overrides: [
          callRingtoneProvider.overrideWithValue(ringtone),
          buzzRepositoryProvider.overrideWithValue(_FakeBuzzRepository()),
        ],
      );
      addTearDown(container.dispose);
    });

    ActiveCallNotifier calls() => container.read(activeCallProvider);

    void ring() => calls().receiveIncomingCall(
      buzzId: 'buzz-1',
      remoteUserId: 'u-1',
      remoteUserName: 'Ada',
      channelId: 'c-1',
    );

    test('an incoming call starts the ringtone once', () {
      ring();
      calls().setFullPage(true); // another update while still ringing

      expect(ringtone.calls, ['start']);
    });

    test('accepting the call stops the ringtone', () async {
      ring();
      await calls().acceptCall();

      expect(calls().state.status, CallStatus.active);
      expect(ringtone.calls, ['start', 'stop']);
    });

    test('declining the call stops the ringtone', () async {
      ring();
      await calls().declineCall();

      expect(calls().state.status, CallStatus.none);
      expect(ringtone.calls, ['start', 'stop']);
    });

    test('the call ending (caller hung up or timed out) stops it', () {
      ring();
      calls().endCall();

      expect(ringtone.calls, ['start', 'stop']);
    });

    test('no ringtone while notifications are paused', () {
      container
          .read(notificationSettingsProvider.notifier)
          .setDndMode(const Duration(hours: 1));

      ring();

      expect(calls().state.status, CallStatus.incoming);
      expect(ringtone.calls, isEmpty);
    });

    test('an outgoing call does not ring', () {
      calls().onRemoteCallDeclined();
      expect(ringtone.calls, isEmpty);
    });

    test('the ringtone asset is bundled', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final data = await rootBundle.load('assets/${AudioCallRingtone.asset}');
      expect(data.lengthInBytes, greaterThan(1000));
    });
  });
}
