import 'package:zedu/features/features.dart';

class CreditPackageModel extends CreditPackage {
  const CreditPackageModel({
    required super.id,
    required super.name,
    required super.description,
    required super.price,
    required super.credits,
    required super.benefits,
    super.planSlug,
  });

  factory CreditPackageModel.fromJson(Map<String, dynamic> json) {
    final benefitsRaw = json['benefits'];
    final benefits = benefitsRaw is List
        ? benefitsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return CreditPackageModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: _asInt(json['price']),
      credits: _asInt(json['credits']),
      benefits: benefits,
      planSlug: json['plan_slug'] as String? ?? json['slug'] as String?,
    );
  }

  /// Reads a whole number from a JSON value that may be a number or a numeric
  /// string. Payment and billing services sometimes encode prices as strings.
  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return num.tryParse(value)?.toInt() ?? 0;
    return 0;
  }
}
