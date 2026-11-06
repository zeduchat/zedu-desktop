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
    final sidebarVisible = ref.watch(sidebarVisibilityProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.backslash, meta: true): () =>
            ref.read(sidebarVisibilityProvider.notifier).toggle(),
        const SingleActivator(
          LogicalKeyboardKey.backslash,
          control: true,
        ): () =>
            ref.read(sidebarVisibilityProvider.notifier).toggle(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: colors.background,
          body: Column(
            children: [
              const _HomeAppBar(),
              const OfflineStatusIndicator(),
              Expanded(
                child: Row(
                  children: [
                    AppSidebarRail(activeType: ref.watch(homeSidebarProvider)),
                    // Buzz is a full-width page, as on the web. The sidebar
                    // stays mounted so it keeps the width the user dragged it to.
                    Visibility(
                      visible:
                          ref.watch(homeSidebarProvider) !=
                          HomeSidebarType.buzz,
                      maintainState: true,
                      child: sidebarVisible
                          ? const ResizableSidebar(
                              child: _MainSidebarSwitcher(),
                            )
                          : const SizedBox(width: 0),
                    ),
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
        ),
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
          const SidebarToggleButton(),
          const SizedBox(width: 4),
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
            child: Semantics(
              button: true,
              label: 'Search messages',
              child: InkWell(
                key: const Key('home-search-messages'),
                borderRadius: BorderRadius.circular(6),
                // #2825: opens workspace message search with From, In and
                // Date filters.
                onTap: () => showMessageSearch(context),
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
    if (state == HomeSidebarType.buzz) {
      return const BuzzView();
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
          // Scrolls when the window is too short for every section.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_drop_down,
                          color: colors.onPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Channels',
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SidebarChannelList(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Material(
                      color: colors.onPrimary.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: colors.onPrimary.withValues(alpha: 0.24),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        hoverColor: colors.onPrimary.withValues(alpha: 0.1),
                        onTap: () => ref
                            .read(activeChatProvider.notifier)
                            .selectChannelDirectory(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'View all channels',
                                  style: TextStyle(
                                    color: colors.onPrimary.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: colors.onPrimary.withValues(alpha: 0.7),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const _AddChannelButton(),
                  const SidebarDmSection(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_right,
                          color: colors.onPrimary,
                          size: 20,
                        ),
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
            ),
          ),
        ],
      ),
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
                ),
        ),
        if (selected?.archived == true)
          _ArchivedChannelBanner(channelName: channelName)
        else
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
    final topic = channel?.topic?.trim() ?? '';

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '# $channelName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                // The topic set in Edit channel, shown under the name so it
                // is visible once saved (#2852); hidden when empty.
                if (topic.isNotEmpty)
                  Text(
                    topic,
                    key: const ValueKey('channel_header_topic'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
              ],
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

/// Replaces the composer of an archived channel: read-only, as on the web.
class _ArchivedChannelBanner extends StatelessWidget {
  const _ArchivedChannelBanner({required this.channelName});

  final String channelName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.divider)),
        color: colors.primaryBg,
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '#$channelName is archived and read-only.',
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
          ),
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
        if (value == 'leave') confirmLeaveChannel(context, ref, channel);
        if (value == 'archive') confirmArchiveChannel(context, ref, channel);
        if (value == 'unarchive') {
          setChannelArchived(context, ref, channel, archived: false);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: channel.archived ? 'unarchive' : 'archive',
          child: Row(
            children: [
              Icon(
                channel.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                size: 18,
                color: colors.textPrimary,
              ),
              const SizedBox(width: 12),
              Text(
                channel.archived ? 'Unarchive channel' : 'Archive channel',
                style: TextStyle(color: colors.textPrimary),
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
