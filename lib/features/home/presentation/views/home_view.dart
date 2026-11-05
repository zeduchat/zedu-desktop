import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCredits(ref.read(creditsOrgIdProvider));
    });
  }

  void _loadCredits(String orgId) {
    if (orgId.isEmpty) return;
    ref.read(creditsNotifierProvider.notifier).load(orgId: orgId);
  }

  @override
  Widget build(BuildContext context) {
    // Switching workspace reloads its credits, so the balance in the user
    // menu belongs to the workspace on screen.
    ref.listen<String>(creditsOrgIdProvider, (previous, next) {
      if (previous != next) _loadCredits(next);
    });
    final colors = context.colors;
    final showProfile = ref.watch(personalProfilePanelProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          const _HomeAppBar(),
          Expanded(
            child: Row(
              children: [
                AppSidebarRail(activeType: ref.watch(homeSidebarProvider)),
                ResizableSidebar(child: const _MainSidebarSwitcher()),
                Expanded(
                  child: Stack(
                    children: [
                      const Positioned.fill(child: _ChatAreaSwitcher()),
                      if (showProfile)
                        const Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: PersonalProfilePanel(),
                        ),
                    ],
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

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final userName =
        ref.watch(authNotifierProvider).user?.fullname ?? 'Zedu User';

    return Container(
      height: 44,
      color: colors.sidebar,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            'Zedu',
            style: TextStyle(
              color: colors.onPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poetsen One',
            ),
          ),
          const SizedBox(width: 12),
          TopUserMenu(userName: userName),
          const Spacer(),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              height: 28,
              decoration: BoxDecoration(
                color: colors.onPrimary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(
                    Icons.search,
                    color: colors.onPrimary.withValues(alpha: 0.7),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Search messages...',
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _MainSidebarSwitcher extends ConsumerWidget {
  const _MainSidebarSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeSidebarProvider);
    if (state == HomeSidebarType.dms) {
      return const DmSidebarList();
    }
    if (state == HomeSidebarType.people) {
      return const PeopleSidebar();
    }
    if (state == HomeSidebarType.files) {
      return const FilesSidebar();
    }
    return const _MainSidebar();
  }
}

class _ChatAreaSwitcher extends ConsumerWidget {
  const _ChatAreaSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeSidebarProvider);
    final selectedDm = ref.watch(selectedDmProvider);
    final activeChat = ref.watch(activeChatProvider);

    void leaveFullPage() {
      final type = ref.read(activeChatProvider).type;
      if (type == ActiveChatType.newGroupChat ||
          type == ActiveChatType.channelDirectory) {
        ref.read(activeChatProvider.notifier).selectChannel('general');
      }
    }

    // Close the New Group Chat and Channel Directory pages when the user
    // switches sidebar tab or opens a conversation.
    ref.listen(homeSidebarProvider, (previous, next) {
      if (previous != next) leaveFullPage();
    });
    ref.listen(selectedDmProvider, (previous, next) {
      if (next != null) leaveFullPage();
    });

    if (activeChat.type == ActiveChatType.newGroupChat) {
      return const NewGroupChatView();
    }
    if (activeChat.type == ActiveChatType.channelDirectory) {
      return const ChannelDirectoryView();
    }

    if (state == HomeSidebarType.dms) {
      if (selectedDm != null) {
        return DmChatArea(conversation: selectedDm);
      } else {
        return const DmEmptyState();
      }
    }
    if (state == HomeSidebarType.people) {
      return const PeopleView();
    }
    if (state == HomeSidebarType.files) {
      return const FilesView();
    }
    return const HomeChatArea();
  }
}

class _MainSidebar extends ConsumerWidget {
  const _MainSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Container(
      color: colors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkspaceSwitcherHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
            child: Row(
              children: [
                Icon(Icons.arrow_drop_down, color: colors.onPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Channels',
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const _ChannelsMenu(),
              ],
            ),
          ),
          const SidebarChannelList(),
          const _AddChannelButton(),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.arrow_right, color: colors.onPrimary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'People',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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

enum _ChannelsMenuAction { create, browse }

class _ChannelsMenu extends ConsumerWidget {
  const _ChannelsMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return PopupMenuButton<_ChannelsMenuAction>(
      tooltip: 'Channel actions',
      iconSize: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 180),
      icon: Icon(
        Icons.more_horiz,
        color: colors.onPrimary.withValues(alpha: 0.7),
      ),
      onSelected: (action) {
        switch (action) {
          case _ChannelsMenuAction.create:
            showDialog<void>(
              context: context,
              builder: (_) => const CreateChannelModal(),
            );
          case _ChannelsMenuAction.browse:
            ref.read(activeChatProvider.notifier).selectChannelDirectory();
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _ChannelsMenuAction.create,
          child: Text('Create a channel'),
        ),
        PopupMenuItem(
          value: _ChannelsMenuAction.browse,
          child: Text('Browse channels'),
        ),
      ],
    );
  }
}

class _AddChannelButton extends StatelessWidget {
  const _AddChannelButton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => const CreateChannelModal(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.onPrimary.withValues(alpha: 0.38),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.add, color: colors.onPrimary, size: 14),
            ),
            const SizedBox(width: 12),
            Text(
              'Add channel',
              style: TextStyle(color: colors.onPrimary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Home pane for the channel picked in the sidebar.
class HomeChatArea extends ConsumerWidget {
  const HomeChatArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Shows the channel picked in the sidebar: its messages, or the welcome
    // text while it has none.
    final chat = ref.watch(activeChatProvider);
    final channels = ref.watch(channelProvider).value ?? const <Channel>[];
    final channelName = chat.type == ActiveChatType.channel
        ? (chat.id ?? 'general')
        : 'general';
    Channel? selected;
    // Two channels can differ only in letter case, so the picked id wins over
    // the name. The name still finds #general at the start, before any pick.
    final pickedId = chat.type == ActiveChatType.channel
        ? chat.channelId
        : null;
    if (pickedId != null) {
      for (final item in channels) {
        if (item.id == pickedId) {
          selected = item;
          break;
        }
      }
    }
    if (selected == null) {
      for (final item in channels) {
        if (item.name.toLowerCase() == channelName.toLowerCase()) {
          selected = item;
          break;
        }
      }
    }

    final channelId = selected?.id ?? '';
    final welcome = _buildWelcomeScreen(context, channelName);
    // Until these load, or if loading fails, the composer simply suggests nobody.
    final members = channelId.isEmpty
        ? const <DmParticipant>[]
        : ref.watch(channelMembersProvider(channelId)).value ??
              const <DmParticipant>[];

    if (channelId.isNotEmpty) {
      // The composer sends through the chat history; reload the list once a
      // send has gone through, so the new message shows.
      ref.listen<int>(
        chatHistoryProvider(channelId).select(
          (history) =>
              history.messages.where((m) => m['status'] == null).length,
        ),
        (previous, next) {
          if (next > (previous ?? 0)) {
            ref.invalidate(channelHistoryProvider(channelId));
          }
        },
      );
    }

    return Column(
      children: [
        _buildChatHeader(context, channelName, selected),
        Expanded(
          child: channelId.isEmpty
              ? welcome
              : ChannelMessageList(
                  key: ValueKey(channelId),
                  channelId: channelId,
                  empty: welcome,
                  unreadCount: selected?.unreadCount ?? 0,
                ),
        ),
        DmMessageComposer(
          key: ValueKey(selected?.id ?? channelName),
          recipientName: '#$channelName',
          channelId: selected?.id ?? '',
          participants: members,
          isChannel: true,
        ),
      ],
    );
  }

  Widget _buildChatHeader(
    BuildContext context,
    String channelName,
    Channel? channel,
  ) {
    final colors = context.colors;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '# $channelName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ),
          _HeaderAction(icon: Icons.headphones_outlined, label: 'Start Buzz'),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 14,
            backgroundColor: colors.accent,
            child: Icon(Icons.person, size: 18, color: colors.onPrimary),
          ),
          const SizedBox(width: 8),
          if (channel == null)
            Icon(Icons.more_vert, color: colors.textHint)
          else
            _ChannelHeaderMenu(channel: channel),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen(BuildContext context, String channelName) {
    final colors = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.celebration, size: 60, color: colors.primary),
          const SizedBox(height: 24),
          Text(
            'Welcome to #$channelName',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share all information relating to $channelName here. All team members await you! 😉',
            style: TextStyle(fontSize: 16, color: colors.textPrimary),
          ),
          const SizedBox(height: 32),
          const _InviteCard(),
        ],
      ),
    );
  }
}

/// The channel header's "more" menu.
class _ChannelHeaderMenu extends ConsumerWidget {
  final Channel channel;

  const _ChannelHeaderMenu({required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return PopupMenuButton<String>(
      key: const ValueKey('channel-header-menu'),
      tooltip: 'Channel options',
      position: PopupMenuPosition.under,
      icon: Icon(Icons.more_vert, color: colors.textHint),
      onSelected: (value) {
        if (value == 'notifications') {
          ChannelNotificationDialog.show(context, channel);
        }
        if (value == 'leave') _confirmLeave(context, ref);
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'notifications',
          child: Row(
            children: [
              Icon(
                Icons.notifications_outlined,
                size: 18,
                color: colors.textPrimary,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Notification settings',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'leave',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: colors.error),
              const SizedBox(width: 12),
              Text('Leave channel', style: TextStyle(color: colors.error)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Leave #${channel.name}?'),
        content: Text(
          channel.isPrivate
              ? 'You will stop getting its messages, and someone will need to '
                    'add you again to rejoin.'
              : 'You will stop getting its messages. You can join it again '
                    'from the channel directory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Leave', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final result = await ref
        .read(channelProvider.notifier)
        .leaveChannel(channel.id);

    switch (result) {
      case Success<void>():
        // Open another channel so the header never shows one we left.
        final remaining = ref.read(channelProvider).value ?? const <Channel>[];
        ref
            .read(activeChatProvider.notifier)
            .selectChannel(
              remaining.isEmpty ? 'general' : remaining.first.name,
            );
        AppToastService.showWith(
          overlay,
          type: AppToastType.success,
          message: 'You left #${channel.name}',
        );
      case Failure<void>(:final error):
        AppToastService.showWith(
          overlay,
          type: AppToastType.error,
          message: error.message.isEmpty
              ? 'Could not leave #${channel.name}'
              : error.message,
        );
    }
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderAction({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.textPrimary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: colors.textPrimary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final inviteButton = AppButton(
          label: 'Invite teammates',
          trailing: const Icon(Icons.arrow_forward, size: 16),
          expand: constraints.maxWidth < 640,
          height: 48,
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16),
            ),
            minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) {
                return BorderSide(color: colors.borderOutline, width: 2);
              }
              return null;
            }),
          ),
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (context) => const InviteTeammatesModal(),
            );
          },
        );

        final invitationDetails = Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.primaryBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person_add_outlined, color: colors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bring your team into Zedu',
                    style: context.textTheme.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Invite teammates to join #general and start collaborating.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        return Card(
          color: colors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: colors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: constraints.maxWidth < 640
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      invitationDetails,
                      const SizedBox(height: 16),
                      inviteButton,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: invitationDetails),
                      const SizedBox(width: 16),
                      inviteButton,
                    ],
                  ),
          ),
        );
      },
    );
  }
}
