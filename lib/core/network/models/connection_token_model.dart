/// The Centrifugo connection token returned by `GET /token/connection`.
class ConnectionTokenModel {
  const ConnectionTokenModel({required this.token});

  final String token;

  factory ConnectionTokenModel.fromJson(Map<String, dynamic> json) {
    return ConnectionTokenModel(token: json['token']?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {'token': token};
}
