import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Left column of the People tab: the workspace's members. Clicking one
/// opens the direct message with them.
class PeopleSidebar extends ConsumerStatefulWidget {
  const PeopleSidebar({super.key});

  @override
  ConsumerState<PeopleSidebar> createState() => _PeopleSidebarState();
}

class _PeopleSidebarState extends ConsumerState<PeopleSidebar> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final members = ref.watch(peopleListProvider(_search));

    return Container(
      width: 320,
      color: colors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkspaceSwitcherHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: PeopleSearchField(
              hintText: 'Find a conversation',
              onDark: true,
              onChanged: (value) => setState(() => _search = value.trim()),
            ),
          ),
          Expanded(
            child: members.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: colors.onPrimary),
              ),
              error: (_, _) => _SidebarMessage(
                text: 'Could not load people',
                onRetry: () => ref.invalidate(peopleListProvider(_search)),
              ),
              data: (list) => list.members.isEmpty
                  ? const _SidebarMessage(text: 'No available member')
                  : _MemberList(search: _search, list: list),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberList extends ConsumerWidget {
  const _MemberList({required this.search, required this.list});

  final String search;
  final PeopleListState list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final opening = ref.watch(peopleActionsProvider);
    final showFooter = list.hasMore || list.isLoadingMore;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 200) {
          ref.read(peopleListProvider(search).notifier).loadMore();
        }
        return false;
      },
      child: Material(
        type: MaterialType.transparency,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: list.members.length + (showFooter ? 1 : 0),
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: colors.onPrimary.withValues(alpha: 0.16),
          ),
          itemBuilder: (context, index) {
            if (index == list.members.length) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: list.isLoadingMore
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary.withValues(alpha: 0.7),
                          ),
                        )
                      // Scrolling near the end loads more; the button also
                      // covers a first page too short to scroll.
                      : TextButton(
                          onPressed: () => ref
                              .read(peopleListProvider(search).notifier)
                              .loadMore(),
                          child: Text(
                            list.loadMoreFailed
                                ? 'Could not load more. Retry'
                                : 'Load more',
                            style: TextStyle(color: colors.onPrimary),
                          ),
                        ),
                ),
              );
            }
            final member = list.members[index];
            return _MemberTile(
              member: member,
              isOpening: opening == member.id,
              onTap: () => openMemberChat(context, ref, member),
            );
          },
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isOpening,
    required this.onTap,
  });

  final OrgMember member;
  final bool isOpening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      hoverColor: colors.onPrimary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            MemberAvatar(member: member),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                member.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onPrimary,
                ),
              ),
            ),
            if (isOpening)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarMessage extends StatelessWidget {
  const _SidebarMessage({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: colors.onPrimary.withValues(alpha: 0.8),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text('Retry', style: TextStyle(color: colors.onPrimary)),
            ),
        ],
      ),
    );
  }
}

/// Opens the DM with [member], or says it could not.
Future<void> openMemberChat(
  BuildContext context,
  WidgetRef ref,
  OrgMember member,
) async {
  // A chat is already opening; let it finish.
  if (ref.read(peopleActionsProvider) != null) return;
  final opened = await ref
      .read(peopleActionsProvider.notifier)
      .openChat(member);
  if (!opened && context.mounted) {
    AppToastService.show(
      context,
      type: AppToastType.error,
      message: "Couldn't open chat. Please try again.",
    );
  }
}
