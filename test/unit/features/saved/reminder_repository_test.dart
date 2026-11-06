import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../helpers/helpers.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late ReminderRepository repository;

  setUp(() {
    api = MockApiBaseService();
    repository = ReminderRepository(api);
  });

  ApiResponseModel<Map<String, dynamic>> ok([
    Map<String, dynamic> body = const {},
  ]) => ApiResponseModel<Map<String, dynamic>>(statusCode: 200, data: body);

  test('lists the pending reminders the server returns', () async {
    when(
      () => api.get<Map<String, dynamic>>(
        path: '/organisations/org-1/reminders',
      ),
    ).thenAnswer(
      (_) async => ok({
        'data': [
          {
            'id': 'rem-1',
            'channels_id': 'chan-1',
            'thread_id': 'thread-1',
            'type': 'thread',
            'preset': '30_min',
            'remind_at': '2026-11-06T10:30:00Z',
            'created_at': '2026-11-06T10:00:00Z',
          },
          {
            'id': 'rem-2',
            'channels_id': 'chan-2',
            'thread_id': 'thread-2',
            'message_id': 'reply-9',
            'type': 'message',
            'preset': 'tomorrow_9am',
            'remind_at': '2026-11-07T08:00:00Z',
          },
        ],
      }),
    );

    final reminders = await repository.list(orgId: 'org-1');

    expect(reminders, hasLength(2));
    expect(reminders.first.id, 'rem-1');
    expect(reminders.first.preset, ReminderPreset.inThirtyMinutes);
    expect(reminders.first.remindAt.toUtc(), DateTime.utc(2026, 11, 6, 10, 30));
    // A reminder is matched to its saved row by this key.
    expect(reminders.first.key, 'chan-1:thread-1');
    expect(reminders.last.messageId, 'reply-9');
    expect(reminders.last.key, 'chan-2:reply-9');
  });

  test('a malformed payload is an empty list, not a crash', () async {
    when(
      () => api.get<Map<String, dynamic>>(
        path: '/organisations/org-1/reminders',
      ),
    ).thenAnswer((_) async => ok({'data': 'nope'}));

    expect(await repository.list(orgId: 'org-1'), isEmpty);
  });

  test('creates a reminder from a preset, with the client UTC offset', () async {
    when(
      () => api.post<Map<String, dynamic>>(
        path: any(named: 'path'),
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => ok({
        'data': {
          'id': 'rem-new',
          'channels_id': 'chan-1',
          'thread_id': 'thread-1',
          'type': 'thread',
          'preset': '1_hour',
          'remind_at': '2026-11-06T11:00:00Z',
        },
      }),
    );

    final created = await repository.create(
      orgId: 'org-1',
      target: const SavedTarget(channelId: 'chan-1', threadId: 'thread-1'),
      preset: ReminderPreset.inOneHour,
      tzOffsetMinutes: 60,
    );

    final call = verify(
      () => api.post<Map<String, dynamic>>(
        path: captureAny(named: 'path'),
        data: captureAny(named: 'data'),
      ),
    ).captured;

    // The same endpoint the web client posts to, so both see the reminder.
    expect(call[0], '/organisations/org-1/reminders');
    final body = call[1] as Map<String, dynamic>;
    expect(body['channels_id'], 'chan-1');
    expect(body['thread_id'], 'thread-1');
    expect(body.containsKey('message_id'), isFalse);
    expect(body['type'], 'thread');
    // The server resolves the preset; the client never sends an instant.
    expect(body['preset'], '1_hour');
    expect(body.containsKey('remind_at'), isFalse);
    // Only tomorrow_9am depends on it, but it is always sent: without it the
    // server would schedule 09:00 UTC, the wrong morning for most users.
    expect(body['tz_offset_minutes'], 60);

    expect(created.id, 'rem-new');
    expect(created.preset, ReminderPreset.inOneHour);
  });

  test('a reply is typed message and carries its own id', () async {
    when(
      () => api.post<Map<String, dynamic>>(
        path: any(named: 'path'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async => ok({'data': {'id': 'r', 'remind_at': ''}}));

    await repository.create(
      orgId: 'org-1',
      target: const SavedTarget(
        channelId: 'chan-1',
        threadId: 'thread-1',
        messageId: 'reply-9',
      ),
      preset: ReminderPreset.tomorrowMorning,
      tzOffsetMinutes: -300,
    );

    final body =
        verify(
              () => api.post<Map<String, dynamic>>(
                path: any(named: 'path'),
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(body['type'], 'message');
    expect(body['message_id'], 'reply-9');
    expect(body['preset'], 'tomorrow_9am');
    expect(body['tz_offset_minutes'], -300);
  });

  test('deletes by the reminder id', () async {
    when(
      () => api.delete<Map<String, dynamic>>(path: any(named: 'path')),
    ).thenAnswer((_) async => ok());

    await repository.delete(orgId: 'org-1', reminderId: 'rem-7');

    verify(
      () => api.delete<Map<String, dynamic>>(
        path: '/organisations/org-1/reminders/rem-7',
      ),
    ).called(1);
  });

  group('presets', () {
    final now = DateTime(2026, 11, 6, 10);

    test('carry the wire values the server validates', () {
      expect(ReminderPreset.inThirtyMinutes.wire, '30_min');
      expect(ReminderPreset.inOneHour.wire, '1_hour');
      expect(ReminderPreset.tomorrowMorning.wire, 'tomorrow_9am');
    });

    test('preview the times the server will resolve them to', () {
      expect(
        ReminderPreset.inThirtyMinutes.resolve(now),
        DateTime(2026, 11, 6, 10, 30),
      );
      expect(ReminderPreset.inOneHour.resolve(now), DateTime(2026, 11, 6, 11));
      expect(
        ReminderPreset.tomorrowMorning.resolve(now),
        DateTime(2026, 11, 7, 9),
      );
    });

    test('tomorrow morning rolls over a month end', () {
      expect(
        ReminderPreset.tomorrowMorning.resolve(DateTime(2026, 11, 30, 23, 50)),
        DateTime(2026, 12, 1, 9),
      );
    });
  });

  test('a reminder is due only once its time has passed', () {
    final reminder = MessageReminder(
      id: 'r',
      channelId: 'c',
      threadId: 't',
      remindAt: DateTime(2026, 11, 6, 10),
    );

    expect(reminder.isDue(DateTime(2026, 11, 6, 9, 59)), isFalse);
    expect(reminder.isDue(DateTime(2026, 11, 6, 10, 1)), isTrue);
  });
}
