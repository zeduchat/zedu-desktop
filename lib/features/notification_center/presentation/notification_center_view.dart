import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// The Notifications page the rail bell opens, laid out like zedu-fe's: the
/// list on the left and the selected notification on the right.
class NotificationCenterView extends ConsumerWidget {
  const NotificationCenterView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Row(
        children: [
          AppSidebarRail(
            activeType: null,
            notificationsSelected: true,
            onTypeSelected: (type) {
              ref.read(homeSidebarProvider.notifier).setType(type);
              context.go(AppRouter.home);
            },
          ),
          const Expanded(child: NotificationCenterBody()),
        ],
      ),
    ),
  );
}

/// The list and detail panes. On narrow windows only one shows at a time:
/// the list, or the selected notification with a back button.
class NotificationCenterBody extends ConsumerStatefulWidget {
  const NotificationCenterBody({super.key});

  static const double listWidth = 340;
  static const double twoPaneMinWidth = 720;

  @override
  ConsumerState<NotificationCenterBody> createState() =>
      _NotificationCenterBodyState();
}

class _NotificationCenterBodyState
    extends ConsumerState<NotificationCenterBody> {
  @override
  void initState() {
    super.initState();
    // Opening the page always shows the latest notifications.
    Future.microtask(() {
      if (mounted) ref.read(notificationCenterProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationCenterProvider);
    final selected = state.selected;
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = _NotificationList(state: state);
        final detail = selected == null
            ? const _NothingSelected()
            : _NotificationDetail(notification: selected);
        if (constraints.maxWidth < NotificationCenterBody.twoPaneMinWidth) {
          if (selected == null) return list;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: TextButton.icon(
                  key: const ValueKey('notifications_back'),
                  onPressed: () => ref
                      .read(notificationCenterProvider.notifier)
                      .clearSelection(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('All notifications'),
                ),
              ),
              Expanded(child: detail),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: NotificationCenterBody.listWidth, child: list),
            Expanded(child: detail),
          ],
        );
      },
    );
  }
}

class _NotificationList extends ConsumerStatefulWidget {
  const _NotificationList({required this.state});

  final NotificationCenterState state;

  @override
  ConsumerState<_NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends ConsumerState<_NotificationList> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      // After a failed page, wait for Retry instead of retrying on scroll.
      if (_controller.position.extentAfter < 200 &&
          ref.read(notificationCenterProvider).loadMoreError == null) {
        ref.read(notificationCenterProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = widget.state;
    final notifier = ref.read(notificationCenterProvider.notifier);

    Widget body;
    if (state.isLoading && state.items.isEmpty) {
      body = Center(child: CircularProgressIndicator(color: colors.onPrimary));
    } else if (state.error != null && state.items.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onPrimary),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: notifier.refresh,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.onPrimary,
                  side: BorderSide(
                    color: colors.onPrimary.withValues(alpha: 0.5),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else if (state.items.isEmpty) {
      body = Center(
        child: Text(
          'No recent notifications',
          style: TextStyle(color: colors.onPrimary),
        ),
      );
    } else {
      body = ListView.separated(
        controller: _controller,
        // One extra row at the end: the spinner while the next page loads,
        // or the error and Retry when it failed.
        itemCount:
            state.items.length +
            (state.isLoadingMore || state.loadMoreError != null ? 1 : 0),
        separatorBuilder: (_, _) => Divider(
          height: 1,
          thickness: 1,
          color: colors.onPrimary.withValues(alpha: 0.15),
        ),
        itemBuilder: (context, index) {
          if (index >= state.items.length && state.loadMoreError != null) {
            return _LoadMoreError(
              message: state.loadMoreError!,
              onRetry: notifier.loadMore,
            );
          }
          if (index >= state.items.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onPrimary,
                  ),
                ),
              ),
            );
          }
          final item = state.items[index];
          return _NotificationRow(
            notification: item,
            unread: state.isUnread(item),
            selected: item.id == state.selectedId,
            onTap: () => notifier.select(item),
          );
        },
      );
    }

    return ColoredBox(
      color: colors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications',
                    style: context.textTheme.titleMedium?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh notifications',
                  onPressed: notifier.refresh,
                  icon: Icon(Icons.refresh, color: colors.onPrimary),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: colors.onPrimary.withValues(alpha: 0.15),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.unread,
    required this.selected,
    required this.onTap,
  });

  final AppNotification notification;
  final bool unread;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final time = notification.sentAt;
    return Material(
      color: selected
          ? colors.onPrimary.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        key: ValueKey('notification_${notification.id}'),
        onTap: onTap,
        hoverColor: colors.onPrimary.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _NotificationAvatar(
                      url: notification.avatarUrl,
                      size: 32,
                      onAccent: true,
                    ),
                    if (unread)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          key: ValueKey('unread_${notification.id}'),
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: colors.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.sidebar, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title.isEmpty
                                ? 'Notification'
                                : notification.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.titleSmall?.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (time != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            formatNotificationTime(context, time),
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colors.onPrimary.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The last row when loading the next page failed: why, and a Retry.
class _LoadMoreError extends StatelessWidget {
  const _LoadMoreError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      key: const ValueKey('notifications_load_more_error'),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.onPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: colors.onPrimary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _NotificationAvatar extends StatelessWidget {
  const _NotificationAvatar({
    required this.url,
    required this.size,
    this.onAccent = false,
  });

  final String url;
  final double size;
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fallback = Container(
      color: onAccent ? colors.primary : colors.primaryBg,
      alignment: Alignment.center,
      child: Icon(
        Icons.notifications_none_outlined,
        size: size / 2,
        color: onAccent ? colors.onPrimary : colors.primary,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        width: size,
        height: size,
        child: url.trim().isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _NothingSelected extends StatelessWidget {
  const _NothingSelected();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colors.primaryBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 44,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select a notification',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationDetail extends ConsumerWidget {
  const _NotificationDetail({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final sentAt = notification.sentAt;
    final channelName = notification.channelName;
    return ColoredBox(
      color: colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification',
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                if (sentAt != null)
                  Text(
                    formatNotificationDate(context, sentAt),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: colors.divider),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        notification.isDirect ? Icons.lock_outline : Icons.tag,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        notification.typeLabel,
                        style: context.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      if (channelName.isNotEmpty) ...[
                        Text('  ·  ', style: TextStyle(color: colors.textHint)),
                        Flexible(
                          child: Text(
                            channelName,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NotificationAvatar(
                        url: notification.avatarUrl,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    notification.displaySender,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                        ),
                                  ),
                                ),
                                if (sentAt != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    formatNotificationTime(context, sentAt),
                                    style: context.textTheme.bodySmall
                                        ?.copyWith(color: colors.textHint),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              notification.message,
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: colors.divider),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.primaryBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channelName.isNotEmpty
                            ? channelName
                            : notification.displaySender,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        notification.isDirect
                            ? 'Reply in your direct message conversation.'
                            : 'View this message in its channel.',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (notification.canOpen)
                  FilledButton.icon(
                    key: const ValueKey('notification_open_conversation'),
                    onPressed: () => openNotificationConversation(
                      context,
                      ref,
                      notification,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      fixedSize: const Size.fromHeight(40),
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Open conversation'),
                  )
                else
                  Text(
                    notification.status.isEmpty
                        ? 'No action available'
                        : notification.status,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the DM, group DM or channel [notification] came from on the Home
/// page, the way Later's "Open conversation" does.
void openNotificationConversation(
  BuildContext context,
  WidgetRef ref,
  AppNotification notification,
) {
  final activeChat = ref.read(activeChatProvider.notifier);
  final sidebar = ref.read(homeSidebarProvider.notifier);
  if (notification.isDirect) {
    final conversations =
        ref.read(dmListProvider).value ?? const <DmConversation>[];
    final matching = conversations.where(
      (c) => c.channelId == notification.channelId,
    );
    final isGroup =
        notification.kind == AppNotificationKind.groupDirectMessage ||
        (matching.isNotEmpty &&
            matching.first.channelType.toLowerCase().contains('group'));
    sidebar.setType(HomeSidebarType.dms);
    if (isGroup) {
      activeChat.selectGroupDm(notification.channelId);
    } else {
      final participantId = matching.isNotEmpty
          ? matching.first.participantId
          : notification.participantId;
      if (participantId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation unavailable. Refresh your DM list.'),
          ),
        );
        return;
      }
      activeChat.selectDirectMessage(participantId);
    }
  } else {
    sidebar.setType(HomeSidebarType.home);
    activeChat.selectChannel(
      notification.channelName,
      channelId: notification.channelId,
    );
  }
  context.go(AppRouter.home);
}

/// "5:31 PM", in the app's locale.
String formatNotificationTime(BuildContext context, DateTime time) =>
    MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(time.toLocal()));

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Thursday, Nov 26 · 5:31 PM", as zedu-fe's detail header.
String formatNotificationDate(BuildContext context, DateTime time) {
  final local = time.toLocal();
  return '${_weekdays[local.weekday - 1]}, ${_months[local.month - 1]} '
      '${local.day} · ${formatNotificationTime(context, local)}';
}
