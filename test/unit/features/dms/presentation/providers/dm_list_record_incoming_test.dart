import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _FakeDmListNotifier extends DmListNotifier {
  _FakeDmListNotifier(this._conversations);

  final List<DmConversation> _conversations;

  @override
  Future<List<DmConversation>> build() async => _conversations;
}

DmConversation _conversation(
  String channelId,
  DateTime lastMessageAt, {
  String channelType = 'dm',
}) => DmConversation(
  channelId: channelId,
  username: 'User $channelId',
  participantId: 'user-$channelId',
  channelType: channelType,
  previewMessage: 'old',
  previewThreads: [
    DmPreviewThread(
      threadId: 't-$channelId',
      message: 'old',
      userId: 'user-$channelId',
      username: 'User $channelId',
      createdAt: lastMessageAt,
    ),
  ],
  unreadCount: 0,
);

void main() {
  late ProviderContainer container;

  setUp(() async {
    container = ProviderContainer(
      overrides: [
        dmListProvider.overrideWith(
          () => _FakeDmListNotifier([
            _conversation('dm-1', DateTime(2026, 11, 20, 12)),
            _conversation(
              'group-1',
              DateTime(2026, 11, 20, 11),
              channelType: 'group_dm',
            ),
            _conversation('dm-2', DateTime(2026, 11, 20, 10)),
          ]),
        ),
      ],
    );
    await container.read(dmListProvider.future);
  });

  tearDown(() => container.dispose());

  /// The list in the order the DMs tab shows it.
  List<String> ordered() {
    final list = [...container.read(dmListProvider).value!]
      ..sort(
        (a, b) =>
            DmSort.recentActivity.compare(a, b, aPinned: false, bPinned: false),
      );
    return list.map((c) => c.channelId).toList();
  }

  Map<String, dynamic> message(String id, DateTime at) => {
    'id': id,
    'user_id': 'someone',
    'username': 'Someone',
    'content': '<p>Hello &amp; welcome</p>',
    'created_at': at.toUtc().toIso8601String(),
  };

  test('a new message moves its DM to the top (#12395)', () {
    expect(ordered(), ['dm-1', 'group-1', 'dm-2']);

    container
        .read(dmListProvider.notifier)
        .recordIncomingMessage('dm-2', message('m1', DateTime(2026, 11, 21)));

    expect(ordered(), ['dm-2', 'dm-1', 'group-1']);
    final dm = container
        .read(dmListProvider)
        .value!
        .firstWhere((c) => c.channelId == 'dm-2');
    expect(dm.previewMessage, 'Hello & welcome');
    expect(dm.lastActivityAt, DateTime(2026, 11, 21));
  });

  test('a new message moves its group chat to the top (#12395)', () {
    container
        .read(dmListProvider.notifier)
        .recordIncomingMessage(
          'group-1',
          message('m1', DateTime(2026, 11, 21)),
        );

    expect(ordered(), ['group-1', 'dm-1', 'dm-2']);
  });

  test('an older message or an unknown channel changes nothing', () {
    final notifier = container.read(dmListProvider.notifier);
    final before = container.read(dmListProvider).value;

    notifier.recordIncomingMessage('dm-2', message('m0', DateTime(2026, 11)));
    notifier.recordIncomingMessage(
      'channel-x',
      message('m1', DateTime(2026, 11, 21)),
    );

    expect(container.read(dmListProvider).value, same(before));
  });
}
