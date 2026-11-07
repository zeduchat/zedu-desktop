import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

void main() {
  testWidgets('Later distinguishes empty and loaded backend lists', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [savedMessagesProvider.overrideWith((ref) async => [])],
        child: const MaterialApp(home: Scaffold(body: LaterBody())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No saved messages.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedMessagesProvider.overrideWith(
            (ref) async => [
              const SavedMessage(
                id: 't1',
                channelId: 'c1',
                preview: 'Review this',
                channelName: 'general',
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LaterBody())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('general'), findsOneWidget);
    expect(find.text('Review this'), findsOneWidget);
    expect(find.byTooltip('Remove from Later'), findsOneWidget);
  });
  testWidgets('Later exposes retry on backend failure', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedMessagesProvider.overrideWith(
            (ref) async => throw Exception('offline'),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LaterBody())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load saved messages.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
