import '../../../../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _FakeChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    Channel(
      id: 'ch-1',
      name: 'general',
      description: '',
      organisationId: 'org-1',
      ownerId: 'u-1',
    ),
  ];
}

class _FakeWebhookService extends Fake implements ChannelWebhookService {
  _FakeWebhookService({this.existing, this.failFetch = false});

  WebhookModel? existing;
  bool failFetch;
  final calls = <String>[];

  @override
  Future<WebhookModel?> fetch(String channelId) async {
    if (failFetch) throw Exception('offline');
    return existing;
  }

  @override
  Future<WebhookModel> create(String channelId, {required String name}) async {
    calls.add('create:$name');
    return existing = WebhookModel(
      id: 'wh-1',
      channelId: channelId,
      name: name,
      slug: 'deploys',
      url: 'https://api.example.com/hooks/deploys',
      isActive: true,
    );
  }

  @override
  Future<WebhookModel?> setActive(
    String channelId,
    String webhookId, {
    required bool active,
  }) async {
    calls.add('active:$active');
    final current = existing!;
    return existing = WebhookModel(
      id: current.id,
      channelId: current.channelId,
      name: current.name,
      slug: current.slug,
      url: current.url,
      isActive: active,
    );
  }

  @override
  Future<void> delete(String channelId, String webhookId) async {
    calls.add('delete');
    existing = null;
  }
}

void main() {
  Future<void> pump(WidgetTester tester, _FakeWebhookService service) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelProvider.overrideWith(_FakeChannelNotifier.new),
          channelWebhookServiceProvider.overrideWithValue(service),
        ],
        child: buildTestMaterialApp(
          const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: WebhooksSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickGeneral(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('webhook-channel-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('# general').last);
    await tester.pumpAndSettle();
  }

  testWidgets('asks the user to pick a channel first', (tester) async {
    await pump(tester, _FakeWebhookService());

    expect(find.text('Pick a channel to see its webhook.'), findsOneWidget);
  });

  testWidgets('a channel without a webhook can create one', (tester) async {
    final service = _FakeWebhookService();
    await pump(tester, service);
    await pickGeneral(tester);

    expect(find.text('This channel has no webhook yet.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('webhook-name-field')),
      'Deploys',
    );
    await tester.tap(find.byKey(const ValueKey('webhook-create')));
    await tester.pumpAndSettle();

    expect(service.calls, ['create:Deploys']);
    expect(find.text('https://api.example.com/hooks/deploys'), findsOneWidget);
  });

  testWidgets('creating without a name asks for one', (tester) async {
    final service = _FakeWebhookService();
    await pump(tester, service);
    await pickGeneral(tester);

    await tester.tap(find.byKey(const ValueKey('webhook-create')));
    await tester.pump();

    expect(find.text('Give the webhook a name.'), findsOneWidget);
    expect(service.calls, isEmpty);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('copies the URL, turns it off and deletes it', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final service = _FakeWebhookService(
      existing: const WebhookModel(
        id: 'wh-1',
        channelId: 'ch-1',
        name: 'Deploys',
        slug: 'deploys',
        url: 'https://api.example.com/hooks/deploys',
        isActive: true,
      ),
    );
    await pump(tester, service);
    await pickGeneral(tester);

    await tester.tap(find.byKey(const ValueKey('webhook-copy')));
    await tester.pump();
    expect(copied, ['https://api.example.com/hooks/deploys']);
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.byKey(const ValueKey('webhook-active')));
    await tester.pumpAndSettle();
    expect(service.calls, ['active:false']);
    expect(find.text('Off'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('webhook-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('webhook-delete-confirm')));
    await tester.pumpAndSettle();

    expect(service.calls, ['active:false', 'delete']);
    expect(find.text('This channel has no webhook yet.'), findsOneWidget);
  });

  testWidgets('offers Retry when the webhook cannot load', (tester) async {
    final service = _FakeWebhookService(failFetch: true);
    await pump(tester, service);
    await pickGeneral(tester);

    expect(find.text('Could not load this channel’s webhook.'), findsOneWidget);

    service.failFetch = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('This channel has no webhook yet.'), findsOneWidget);
  });
}
