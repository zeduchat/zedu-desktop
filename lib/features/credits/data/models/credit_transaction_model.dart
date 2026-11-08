import 'package:zedu/features/features.dart';

class CreditTransactionModel extends CreditTransaction {
  const CreditTransactionModel({
    required super.id,
    required super.amount,
    required super.credits,
    required super.status,
    required super.createdAt,
  });

  /// Used when a transaction has no usable date. A fixed epoch keeps sorting
  /// deterministic instead of making an old row look like a new purchase.
  static final DateTime _unknownCreatedAt = DateTime.fromMillisecondsSinceEpoch(
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
      createdAt: createdRaw != null
          ? DateTime.tryParse(createdRaw) ?? _unknownCreatedAt
          : _unknownCreatedAt,
    );
  }
}
