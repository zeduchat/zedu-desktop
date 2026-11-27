import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

abstract interface class UserProfileRepository {
  Future<Result<ProfileAccount>> getAccount();
  Future<Result<ProfileAccount>> updateAccount(ProfileAccount account);
  Future<Result<void>> uploadAvatar(String filePath);
  Future<Result<void>> removeAvatar();
  Future<Result<void>> deleteAccount();

  Future<Result<NotificationPreferences>> getNotificationPreferences({
    required String? orgId,
  });
  Future<Result<NotificationPreferences>> updateNotificationPreferences({
    required String? orgId,
    required NotificationPreferences preferences,
  });

  /// The signed-in user's sessions ([userId] is their user id).
  Future<Result<List<SecuritySession>>> getSecuritySessions({
    required String userId,
  });
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Result<OrganizationProfile>> getOrganization({String? orgId});
  Future<Result<OrganizationProfile>> createOrganization({
    required String name,
    required String type,
    required String country,
  });
  Future<Result<OrganizationProfile>> updateOrganization(
    OrganizationProfile organization, {
    String? orgId,
  });
  Future<Result<void>> deleteOrganization({required String orgId});

  Future<Result<List<TeamMember>>> getTeamMembers({String? orgId});
  Future<Result<TeamMember>> inviteMember({
    required String email,
    required String role,
    required String orgId,
  });
  Future<Result<TeamMember>> updateMember(TeamMember member);
  Future<Result<void>> removeMember(String memberId);
  Future<Result<List<RolePermission>>> getRolesAndPermissions({String? orgId});
  Future<Result<BillingInfo>> getBillingInfo();
}
