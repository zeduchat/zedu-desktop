import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullname,
    required this.email,
    required this.phone,
    required this.username,
    required this.isVerified,
    required this.isOnboarded,
    required this.createdAt,
    required this.updatedAt,
    required this.avatarUrl,
    required this.currentOrg,
    required this.currentOrganisationSlug,
    required this.defaultAvatarUrl,
    required this.expiresIn,
    required this.isActive,
    required this.online,
    required this.organisation,
    required this.profileUpdated,
    required this.userId,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String fullname;
  final String email;
  final String phone;
  final String username;
  final bool isVerified;
  final bool isOnboarded;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String avatarUrl;
  final String currentOrg;
  final String currentOrganisationSlug;
  final String defaultAvatarUrl;
  final DateTime expiresIn;
  final bool isActive;
  final bool online;
  final OrganisationModel organisation;
  final bool profileUpdated;
  final String userId;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? json['user_id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      fullname: json['fullname'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      username: json['username'] as String? ?? '',
      isVerified: json['is_verified'] as bool? ?? false,
      isOnboarded: json['is_onboarded'] as bool? ?? false,
      createdAt: parseApiTimestampOrEpoch(json['created_at']),
      updatedAt: parseApiTimestampOrEpoch(json['updated_at']),
      avatarUrl: json['avatar_url'] as String? ?? '',
      currentOrg: json['current_org'] as String? ?? '',
      currentOrganisationSlug:
          json['current_organisation_slug'] as String? ?? '',
      defaultAvatarUrl: json['default_avatar_url'] as String? ?? '',
      expiresIn: parseApiTimestampOrEpoch(json['expires_in']),
      isActive: json['is_active'] as bool? ?? false,
      online: json['online'] as bool? ?? false,
      organisation: OrganisationModel.fromJson(
        (json['organisation'] is Map<String, dynamic>
            ? json['organisation'] as Map<String, dynamic>
            : <String, dynamic>{}),
      ),
      profileUpdated: json['profile_updated'] as bool? ?? false,
      userId: json['user_id'] as String? ?? json['id'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'fullname': fullname,
    'email': email,
    'phone': phone,
    'username': username,
    'is_verified': isVerified,
    'is_onboarded': isOnboarded,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'avatar_url': avatarUrl,
    'current_org': currentOrg,
    'current_organisation_slug': currentOrganisationSlug,
    'default_avatar_url': defaultAvatarUrl,
    'expires_in': expiresIn.toIso8601String(),
    'is_active': isActive,
    'online': online,
    'organisation': organisation,
    'profile_updated': profileUpdated,
    'user_id': userId,
  };

  User toEntity() => User(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: email,
    phone: phone,
    username: username,
    isVerified: isVerified,
    isOnboarded: isOnboarded,
    createdAt: createdAt,
    currentOrg: currentOrg,
    currentOrganisationSlug: currentOrganisationSlug,
    avatarUrl: avatarUrl,
    defaultAvatarUrl: defaultAvatarUrl,
    creditBalance: organisation.creditBalance,
    subscriptionPlanId: organisation.subscriptionPlanId,
    aiCreditsPurchasable:
        organisation.organisationPlan.planDetails.aiCreditsPurchasable,
    status: UserStatus(online: online),
  );
}
