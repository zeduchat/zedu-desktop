import 'package:zedu/features/features.dart';

class CreditTransactionModel extends CreditTransaction {
  const CreditTransactionModel({
    required super.id,
    required super.amount,
    required super.credits,
    required super.status,
    required super.createdAt,
  });

  /// The date given to a transaction whose `created_at` is missing or can't
  /// be parsed: the Unix epoch in UTC. It is fixed, so such a record sorts
  /// last in a newest-first history instead of passing as one made just now.
  static final unknownCreatedAt = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );

  factory CreditTransactionModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'] as String?;
    return CreditTransactionModel(
      id: json['id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      credits: (json['credits'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'completed',
      createdAt:
          (createdRaw == null ? null : DateTime.tryParse(createdRaw)) ??
          unknownCreatedAt,
    );
  }
}
