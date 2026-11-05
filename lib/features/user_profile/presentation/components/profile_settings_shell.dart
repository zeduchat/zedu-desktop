import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class ProfileSettingsShell extends ConsumerWidget {
  const ProfileSettingsShell({
    super.key,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.child,
  });

  final UserProfileSection selectedSection;
  final ValueChanged<UserProfileSection> onSectionSelected;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userProfileNotifierProvider);
    final authState = ref.watch(authNotifierProvider);

    String userName = 'Zedu User';
    if (authState.user != null && authState.user!.username.isNotEmpty) {
      userName = authState.user!.username;
    } else if (state.account?.name != null && state.account!.name.isNotEmpty) {
      userName = state.account!.name;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _ProfileTopBar(userName: userName),
            Expanded(
              child: Row(
                children: [
                  AppSidebarRail(
                    activeType: null,
                    settingsSelected: true,
                    onTypeSelected: (type) {
                      ref.read(homeSidebarProvider.notifier).setType(type);
                      context.go(AppRouter.home);
                    },
                  ),
                  _SettingsNavigation(
                    userName: userName,
                    selectedSection: selectedSection,
                    onSectionSelected: onSectionSelected,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Expanded(child: child)],
                    ),
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

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({required this.userName});
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: context.colors.sidebar,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Image.asset(
            'assets/pngs/zedu_logo.png',
            width: 82,
            height: 31,
            color: Colors.white,
            colorBlendMode: BlendMode.srcIn,
          ),
          const SizedBox(width: 24),
          TopUserMenu(
            userName: userName,
            backgroundColor: context.colors.primary.withValues(alpha: 0.58),
          ),
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search messages...',
                hintStyle: context.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white,
                  size: 18,
                ),
                filled: true,
                fillColor: context.colors.onPrimary.withValues(alpha: 0.16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: context.textTheme.bodySmall?.copyWith(color: Colors.white),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _SettingsNavigation extends StatelessWidget {
  const _SettingsNavigation({
    required this.userName,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final String userName;
  final UserProfileSection selectedSection;
  final ValueChanged<UserProfileSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      color: context.colors.sidebar,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scrolls so the version row stays on screen in a short window.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: context.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          userName,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const _NavigationGroupLabel(label: 'Personal'),
                  _NavigationTile(
                    icon: Icons.person_outline,
                    label: 'Account',
                    selected: selectedSection == UserProfileSection.account,
                    onTap: () => onSectionSelected(UserProfileSection.account),
                  ),
                  _NavigationTile(
                    icon: Icons.notifications_none,
                    label: 'Notifications',
                    selected:
                        selectedSection == UserProfileSection.notifications,
                    onTap: () =>
                        onSectionSelected(UserProfileSection.notifications),
                  ),
                  _NavigationTile(
                    icon: Icons.lock_outline,
                    label: 'Security',
                    selected: selectedSection == UserProfileSection.security,
                    onTap: () => onSectionSelected(UserProfileSection.security),
                  ),
                  const SizedBox(height: 18),
                  const _NavigationGroupLabel(label: 'Organization'),
                  _NavigationTile(
                    icon: Icons.settings_outlined,
                    label: 'General',
                    selected:
                        selectedSection == UserProfileSection.organization,
                    onTap: () =>
                        onSectionSelected(UserProfileSection.organization),
                  ),
                  _NavigationTile(
                    icon: Icons.groups_outlined,
                    label: 'User management',
                    selected:
                        selectedSection == UserProfileSection.userManagement,
                    onTap: () =>
                        onSectionSelected(UserProfileSection.userManagement),
                  ),
                  _NavigationTile(
                    icon: Icons.person_outline,
                    label: 'Roles & permissions',
                    selected:
                        selectedSection ==
                        UserProfileSection.rolesAndPermissions,
                    onTap: () => onSectionSelected(
                      UserProfileSection.rolesAndPermissions,
                    ),
                  ),
                  _NavigationTile(
                    icon: Icons.webhook_outlined,
                    label: 'Webhooks',
                    selected: selectedSection == UserProfileSection.webhooks,
                    onTap: () => onSectionSelected(UserProfileSection.webhooks),
                  ),
                  _NavigationTile(
                    icon: Icons.credit_card_outlined,
                    label: 'Billing',
                    selected: selectedSection == UserProfileSection.billing,
                    onTap: () => onSectionSelected(UserProfileSection.billing),
                  ),
                ],
              ),
            ),
          ),
          const AppVersionRow(),
        ],
      ),
    );
  }
}

class _NavigationGroupLabel extends StatelessWidget {
  const _NavigationGroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? context.colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
