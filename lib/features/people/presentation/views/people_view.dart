import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Main area of the People tab: the workspace's members as cards. Clicking
/// one opens the direct message with them.
class PeopleView extends ConsumerStatefulWidget {
  const PeopleView({super.key});

  @override
  ConsumerState<PeopleView> createState() => _PeopleViewState();
}

class _PeopleViewState extends ConsumerState<PeopleView> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final members = ref.watch(peopleListProvider(_search));

    return Container(
      color: colors.onPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: PeopleSearchField(
              hintText: 'Search for people',
              onChanged: (value) => setState(() => _search = value.trim()),
            ),
          ),
          Expanded(
            child: members.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: colors.primary),
              ),
              error: (_, _) => _Message(
                text: 'Could not load members.',
                onRetry: () => ref.invalidate(peopleListProvider(_search)),
              ),
              data: (list) => list.members.isEmpty
                  ? _Message(
                      text: _search.isEmpty
                          ? 'No members yet.'
                          : 'No members found matching your search.',
                    )
                  : _MemberGrid(search: _search, list: list),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'People',
              style: context.textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          _HeaderButton(
            icon: Icons.person_add_alt_1_outlined,
            label: 'Invite People',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const InviteTeammatesModal(),
            ),
          ),
          const SizedBox(width: 12),
          _HeaderButton(
            icon: Icons.add,
            label: 'New Chat',
            onPressed: () =>
                ref.read(activeChatProvider.notifier).selectNewGroupChat(),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.borderOutline),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: context.textTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _MemberGrid extends ConsumerWidget {
  const _MemberGrid({required this.search, required this.list});

  final String search;
  final PeopleListState list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final notifier = ref.read(peopleListProvider(search).notifier);
    final opening = ref.watch(peopleActionsProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 270,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final member = list.members[index];
              return _MemberCard(
                member: member,
                isOpening: opening == member.id,
                onTap: () => openMemberChat(context, ref, member),
              );
            }, childCount: list.members.length),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Showing ${list.members.length} of ${list.total} members',
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: colors.textHint,
                    ),
                  ),
                ),
                if (list.hasMore)
                  OutlinedButton(
                    onPressed: list.isLoadingMore ? null : notifier.loadMore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.divider),
                      textStyle: context.textTheme.labelLarge?.copyWith(
                        fontSize: 13,
                      ),
                    ),
                    child: list.isLoadingMore
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          )
                        : Text(
                            list.loadMoreFailed
                                ? 'Could not load more. Retry'
                                : 'Load more',
                          ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
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
    final detail = context.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      color: colors.textHint,
    );

    return Material(
      color: colors.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => MemberAvatar(
                  member: member,
                  size: constraints.maxWidth,
                  radius: 0,
                  showPresence: false,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (isOpening)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        ),
                    ],
                  ),
                  if (member.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      member.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: detail,
                    ),
                  ],
                  if (member.phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      member.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: detail,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: member.online
                              ? colors.presenceActive
                              : colors.divider,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        member.online ? 'Online' : 'Offline',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 40, color: colors.textHint),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: colors.textHint,
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
