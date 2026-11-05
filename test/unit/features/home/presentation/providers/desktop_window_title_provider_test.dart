import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('formatDesktopWindowTitle', () {
    test('returns appName when no context or workspace is provided', () {
      expect(formatDesktopWindowTitle(), 'Zedu');
      expect(formatDesktopWindowTitle(appName: 'CustomApp'), 'CustomApp');
    });

    test('formats workspace title when contextName is absent', () {
      expect(
        formatDesktopWindowTitle(workspaceName: 'Acme Corp'),
        'Acme Corp · Zedu',
      );
    });

    test('formats channel conversation title', () {
      expect(
        formatDesktopWindowTitle(
          contextName: 'General',
          workspaceName: 'Acme Corp',
        ),
        'General · Zedu',
      );
    });

    test('formats direct message conversation title', () {
      expect(
        formatDesktopWindowTitle(
          contextName: 'Ada Okafor',
          workspaceName: 'Acme Corp',
        ),
        'Ada Okafor · Zedu',
      );
    });

    test('prefixes unread count when unreadCount > 0', () {
      expect(
        formatDesktopWindowTitle(
          contextName: 'General',
          workspaceName: 'Acme Corp',
          unreadCount: 3,
        ),
        '(3) General · Zedu',
      );

      expect(
        formatDesktopWindowTitle(
          contextName: 'Ada Okafor',
          workspaceName: 'Acme Corp',
          unreadCount: 1,
        ),
        '(1) Ada Okafor · Zedu',
      );
    });

    test('handles whitespace padding cleanly', () {
      expect(
        formatDesktopWindowTitle(
          contextName: '   Dev Channel   ',
          workspaceName: 'Acme',
        ),
        'Dev Channel · Zedu',
      );
    });
  });

  group('desktopWindowTitleProvider in container', () {
    test('defaults to Zedu when unauthenticated', () {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(
              const AuthState(status: AuthStatus.unauthenticated),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final title = container.read(desktopWindowTitleProvider);
      expect(title, 'Zedu');
    });

    test('updates title when active channel and workspace are present', () {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(
              const AuthState(status: AuthStatus.authenticated),
            ),
          ),
          workspaceProvider.overrideWith(
            () => _FakeWorkspaceNotifier(
              const WorkspaceState(
                selectedWorkspace: Workspace(
                  id: 'ws-1',
                  name: 'Zedu Workspace',
                  avatar: '',
                  channelsCount: 5,
                ),
              ),
            ),
          ),
          activeChatProvider.overrideWith(
            () => _FakeActiveChatNotifier(
              const ActiveChatState(
                type: ActiveChatType.channel,
                id: 'general',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final title = container.read(desktopWindowTitleProvider);
      expect(title, 'General · Zedu');
    });

    test('updates title for DM conversation with unread count', () {
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(
              const AuthState(status: AuthStatus.authenticated),
            ),
          ),
          workspaceProvider.overrideWith(
            () => _FakeWorkspaceNotifier(
              const WorkspaceState(
                selectedWorkspace: Workspace(
                  id: 'ws-1',
                  name: 'Zedu Workspace',
                  avatar: '',
                  channelsCount: 5,
                ),
              ),
            ),
          ),
          activeChatProvider.overrideWith(
            () => _FakeActiveChatNotifier(
              const ActiveChatState(
                type: ActiveChatType.directMessage,
                id: 'user-2',
              ),
            ),
          ),
          selectedDmProvider.overrideWith(
            () => _FakeSelectedDmNotifier(
              DmConversation(
                channelId: 'dm-1',
                username: 'Ada Okafor',
                participantId: 'user-2',
                previewMessage: 'Hello',
                unreadCount: 0,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final title = container.read(desktopWindowTitleProvider);
      expect(title, 'Ada Okafor · Zedu');
    });
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  final WorkspaceState _initial;
  _FakeWorkspaceNotifier(this._initial);

  @override
  WorkspaceState build() => _initial;
}

class _FakeActiveChatNotifier extends ActiveChatNotifier {
  final ActiveChatState _initial;
  _FakeActiveChatNotifier(this._initial);

  @override
  ActiveChatState build() => _initial;
}

class _FakeSelectedDmNotifier extends SelectedDmNotifier {
  final DmConversation? _initial;
  _FakeSelectedDmNotifier(this._initial);

  @override
  DmConversation? build() => _initial;
}
