import "package:zedu/features/features.dart";

class LoginResponseModel {
  const LoginResponseModel({
    required this.user,
    required this.accessToken,
    required this.accessTokenExpiresIn,
    required this.notificationToken,
  });

  final UserModel user;
  final String accessToken;
  final DateTime accessTokenExpiresIn;
  final String notificationToken;

  static DateTime _parseDate(Object? raw) {
    if (raw == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (raw is int) {
      return raw > 100000000000
          ? DateTime.fromMillisecondsSinceEpoch(raw)
          : DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    if (raw is num) {
      final val = raw.toInt();
      return val > 100000000000
          ? DateTime.fromMillisecondsSinceEpoch(val)
          : DateTime.fromMillisecondsSinceEpoch(val * 1000);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      final seconds = int.tryParse(trimmed);
      if (seconds != null) {
        return seconds > 100000000000
            ? DateTime.fromMillisecondsSinceEpoch(seconds)
            : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
      final iso = DateTime.tryParse(trimmed);
      if (iso != null) return iso;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final rawUser = json["user"];
    if (rawUser is! Map) {
      throw const FormatException('Login response has no user object');
    }

    return LoginResponseModel(
      user: UserModel.fromJson(Map<String, dynamic>.from(rawUser)),
      accessToken: json["access_token"] as String? ?? "",
      accessTokenExpiresIn: _parseDate(json["access_token_expires_in"]),
      notificationToken: json["notification_token"] as String? ?? "",
    );
  }

  Map<String, dynamic> toJson() => {
    "user": user.toJson(),
    "access_token": accessToken,
    "access_token_expires_in": accessTokenExpiresIn.toIso8601String(),
    "notification_token": notificationToken,
  };
}
