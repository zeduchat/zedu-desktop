import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class _Workspace extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org', name: 'Org', avatar: ''),
  );
}

void main() {
  testWidgets('channel management filters active and archived rows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceProvider.overrideWith(_Workspace.new),
          managedChannelsProvider.overrideWith(
            (ref) async => [
              ManagedChannel(
                Channel(
                  id: 'c1',
                  name: 'active-channel',
                  description: '',
                  organisationId: 'org',
                  ownerId: '',
                ),
              ),
              ManagedChannel(
                Channel(
                  id: 'c2',
                  name: 'archived-channel',
                  description: '',
                  organisationId: 'org',
                  ownerId: '',
                  archived: true,
                ),
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ChannelManagementSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('#active-channel'), findsOneWidget);
    expect(find.text('#archived-channel'), findsNothing);
    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('#archived-channel'), findsOneWidget);
    expect(find.text('#active-channel'), findsNothing);
  });
}
