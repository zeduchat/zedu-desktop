import '../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class FakeChannelNotificationService extends Fake
    implements ChannelNotificationService {
  FakeChannelNotificationService(this.stored, {this.failLoad = false});

  ChannelNotificationPreference stored;
  final bool failLoad;
  ChannelNotificationPreference? saved;

  @override
  Future<ChannelNotificationPreference> load(String channelId) async {
    if (failLoad) throw Exception('offline');
    return stored;
  }

  @override
  Future<void> save(
    String channelId,
    ChannelNotificationPreference preference,
  ) async {
    saved = preference;
  }
}

final _channel = Channel(
  id: 'ch-1',
  name: 'general',
  description: '',
  organisationId: 'org-1',
  ownerId: 'u-1',
);

void main() {
  Future<void> pumpDialog(
    WidgetTester tester,
    FakeChannelNotificationService service,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelNotificationServiceProvider.overrideWithValue(service),
        ],
        child: buildTestMaterialApp(
          Scaffold(body: ChannelNotificationDialog(channel: _channel)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the saved choice and saves a new one', (tester) async {
    final service = FakeChannelNotificationService(
      const ChannelNotificationPreference(
        level: ChannelNotificationLevel.mentions,
      ),
    );
    await pumpDialog(tester, service);

    expect(find.text('Notifications for #general'), findsOneWidget);
    final group = tester.widget<RadioGroup<ChannelNotificationLevel>>(
      find.byKey(const ValueKey('channel-notification-level')),
    );
    expect(group.groupValue, ChannelNotificationLevel.mentions);

    await tester.tap(find.text('All new messages'));
    await tester.tap(find.text('Mute this channel'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('channel-notification-save')));
    await tester.pumpAndSettle();
    // Let the "saved" toast finish, so no timer is left running.
    await tester.pump(const Duration(seconds: 5));

    expect(service.saved?.level, ChannelNotificationLevel.all);
    expect(service.saved?.muted, isTrue);
  });

  testWidgets('offers Retry when the settings cannot load', (tester) async {
    final service = FakeChannelNotificationService(
      const ChannelNotificationPreference(),
      failLoad: true,
    );
    await pumpDialog(tester, service);

    expect(
      find.text('Could not load your notification settings.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('channel-notification-save')),
    );
    expect(save.onPressed, isNull);
  });
}
