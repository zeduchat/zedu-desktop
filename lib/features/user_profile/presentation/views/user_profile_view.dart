import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class UserProfileView extends ConsumerWidget {
  const UserProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<UserProfileState>(userProfileNotifierProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          AppToastService.show(
            context,
            type: AppToastType.error,
            message: next.error!,
          );
        });
      }
      if (next.successMessage != null &&
          previous?.successMessage != next.successMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          AppToastService.show(
            context,
            type: AppToastType.success,
            message: next.successMessage!,
          );
        });
      }
    });

    final state = ref.watch(userProfileNotifierProvider);
    final notifier = ref.read(userProfileNotifierProvider.notifier);
    final authenticatedUser = ref.watch(authNotifierProvider).user;
    final workspaceName = ref.watch(
      workspaceProvider.select((s) => s.selectedWorkspace?.name),
    );

    return ProfileSettingsShell(
      selectedSection: state.section,
      onSectionSelected: notifier.selectSection,
      child: _ProfileContent(
        state: state,
        notifier: notifier,
        authenticatedUser: authenticatedUser,
        workspaceName: workspaceName,
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.state,
    required this.notifier,
    required this.authenticatedUser,
    required this.workspaceName,
  });

  final UserProfileState state;
  final UserProfileNotifier notifier;
  final User? authenticatedUser;
  final String? workspaceName;

  static const padding = EdgeInsets.fromLTRB(28, 32, 40, 48);
  static const maxContentWidth = 1000.0;

  @override
  Widget build(BuildContext context) {
    final organization = state.organization;
    // Notifications scrolls on its own so its unsaved-changes bar can stay
    // pinned below the scrolling content.
    if (state.section == UserProfileSection.notifications) {
      return NotificationsSection(
        preferences: state.notifications ?? NotificationPreferences.empty(),
        isSaving: state.isSaving,
        onSave: notifier.updateNotificationPreferences,
        workspaceName: workspaceName,
        padding: padding,
        maxContentWidth: maxContentWidth,
      );
    }
    return SingleChildScrollView(
      padding: padding,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: switch (state.section) {
            UserProfileSection.account => AccountSection(
              account: accountForAuthenticatedUser(
                state.account ??
                    (authenticatedUser != null
                        ? profileAccountFromAuthUser(authenticatedUser!)
                        : ProfileAccount.empty()),
                authenticatedUser,
              ),
              isSaving: state.isSaving,
              onSave: notifier.updateAccount,
              onDelete: notifier.deleteAccount,
            ),
            UserProfileSection.notifications => const SizedBox.shrink(),
            UserProfileSection.security => SecuritySection(
              sessions: state.securitySessions,
              isSaving: state.isSaving,
              onChangePassword: notifier.changePassword,
            ),
            UserProfileSection.organization =>
              organization == null
                  ? _OrganizationLoadError(
                      isLoading: state.isLoading,
                      onRetry: notifier.load,
                    )
                  : OrganizationSection(
                      organization: organization,
                      isSaving: state.isSaving,
                      onSave: notifier.updateOrganization,
                      onDelete: notifier.deleteOrganization,
                      onLeave: notifier.leaveOrganization,
                    ),
            UserProfileSection.userManagement => UserManagementSection(
              members: state.teamMembers,
              isSaving: state.isSaving,
              onInvite: notifier.inviteMember,
              onUpdate: notifier.updateMember,
              onRemove: notifier.removeMember,
            ),
            UserProfileSection.rolesAndPermissions =>
              RolesAndPermissionsSection(roles: state.rolesAndPermissions),
            UserProfileSection.webhooks => const WebhooksSection(),
            UserProfileSection.billing => BillingSection(
              billing: state.billing ?? BillingInfo.empty(),
              onInvite: notifier.inviteMember,
            ),
          },
        ),
      ),
    );
  }
}

/// Shown instead of made-up values when the organization details can't be
/// loaded.
class _OrganizationLoadError extends StatelessWidget {
  const _OrganizationLoadError({
    required this.isLoading,
    required this.onRetry,
  });

  final bool isLoading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "We couldn't load your organization details.",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text('Check your connection and try again.'),
        const SizedBox(height: 16),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}

/// Builds a [ProfileAccount] from the authenticated user's data, avoiding
/// placeholder "Anonymous user" values. Used when the profile account hasn't
/// been loaded from the server yet.
@visibleForTesting
ProfileAccount profileAccountFromAuthUser(User authenticatedUser) {
  final name = authenticatedUser.fullname.trim().isNotEmpty
      ? authenticatedUser.fullname.trim()
      : authenticatedUser.username;
  return ProfileAccount(
    name: name.isNotEmpty ? name : 'User',
    email: authenticatedUser.email,
    timezone: '',
    avatarUrl: authenticatedUser.avatarUrl,
    username: authenticatedUser.username,
  );
}

/// Populates an account with the authenticated user's credentials if the
/// loaded account still contains placeholder values.
@visibleForTesting
ProfileAccount accountForAuthenticatedUser(ProfileAccount account, User? user) {
  if (user == null) return account;
  return account.copyWith(
    name: _firstNonPlaceholder([account.name, user.fullname, user.username]),
    email: _firstNonPlaceholder([account.email, user.email]),
    username: _firstNonPlaceholder([account.username, user.username]),
    avatarUrl:
        (account.avatarUrl != null && account.avatarUrl!.trim().isNotEmpty)
        ? account.avatarUrl
        : user.avatarUrl,
  );
}

String _firstNonPlaceholder(List<String> values) {
  const placeholders = {
    'anonymous user',
    'anonymoususer',
    'anonymoususer@email.com',
  };
  for (final val in values) {
    final trimmed = val.trim();
    if (trimmed.isNotEmpty && !placeholders.contains(trimmed.toLowerCase())) {
      return trimmed;
    }
  }
  return values.firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');
}
