import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Opens the conversation a `zedu://chat/...` deep link points at, either the
/// app's initial link or one that arrives while it is running, and hands the
/// linked message id to the chat area so it scrolls to the message.
class ChatDeepLinkListener extends ConsumerStatefulWidget {
  const ChatDeepLinkListener({super.key, required this.child, this.appLinks});

  final Widget child;
  final AppLinks? appLinks;

  @override
  ConsumerState<ChatDeepLinkListener> createState() =>
      _ChatDeepLinkListenerState();
}

class _ChatDeepLinkListenerState extends ConsumerState<ChatDeepLinkListener> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  String? _lastHandledLink;

  static const _tag = 'ChatDeepLinkListener';

  @override
  void initState() {
    super.initState();
    _appLinks = widget.appLinks ?? AppLinks();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleUri(initialUri);
      }
    } catch (error) {
      AppLogger.w('Failed to read initial chat deep link', tag: _tag);
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleUri(uri)),
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.w('Chat deep link stream error: $error', tag: _tag);
      },
    );
  }

  Future<void> _handleUri(Uri uri) async {
    final target = ChatDeepLinkParser.extractTarget(uri);
    if (target == null) return;
    final link = uri.toString();
    if (link == _lastHandledLink) return;
    _lastHandledLink = link;

    final authState = ref.read(authNotifierProvider);
    if (authState.status != AuthStatus.authenticated) {
      AppLogger.i('Ignoring chat deep link while signed out', tag: _tag);
      return;
    }

    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator == null) return;

    DmConversation? conversation;
    try {
      final conversations = await ref.read(dmListProvider.future);
      for (final candidate in conversations) {
        if (candidate.channelId == target.channelId) {
          conversation = candidate;
          break;
        }
      }
    } catch (error) {
      AppLogger.w('Failed to look up deep-linked conversation', tag: _tag);
    }
    // The list may not have this conversation yet; a minimal entry is enough
    // for the chat area to fetch the channel's messages.
    conversation ??= DmConversation(
      channelId: target.channelId,
      username: '',
      participantId: '',
      previewMessage: '',
      unreadCount: 0,
    );

    if (!mounted) return;
    ref.read(homeSidebarProvider.notifier).setType(HomeSidebarType.dms);
    ref.read(pendingMessageJumpProvider.notifier).state = PendingMessageJump(
      channelId: target.channelId,
      messageId: target.messageId ?? '',
    );
    ref.read(selectedDmProvider.notifier).select(conversation);
    navigator.context.go(AppRouter.home);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
