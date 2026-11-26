import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

Map<String, dynamic> _json({Object? createdAt = _omit}) => {
  'id': 'tx_1',
  'amount': 500,
  'credits': 50,
  'status': 'completed',
  if (!identical(createdAt, _omit)) 'created_at': createdAt,
};

const _omit = Object();

void main() {
  group('CreditTransactionModel.fromJson created_at', () {
    test('parses a valid ISO-8601 timestamp', () {
      final model = CreditTransactionModel.fromJson(
        _json(createdAt: '2026-03-14T09:30:00Z'),
      );

      expect(model.createdAt, DateTime.utc(2026, 3, 14, 9, 30));
    });

    test('uses the fixed epoch, not the current time, when it is invalid', () {
      final model = CreditTransactionModel.fromJson(
        _json(createdAt: 'not-a-date'),
      );

      expect(model.createdAt, CreditTransactionModel.unknownCreatedAt);
      expect(model.createdAt, DateTime.utc(1970));
    });

    test('uses the fixed epoch when it is missing or null', () {
      expect(
        CreditTransactionModel.fromJson(_json()).createdAt,
        CreditTransactionModel.unknownCreatedAt,
      );
      expect(
        CreditTransactionModel.fromJson(_json(createdAt: null)).createdAt,
        CreditTransactionModel.unknownCreatedAt,
      );
    });

    test('an unparseable record sorts last in a newest-first history', () {
      final transactions = [
        CreditTransactionModel.fromJson(_json(createdAt: 'garbage')),
        CreditTransactionModel.fromJson(
          _json(createdAt: '2026-01-02T00:00:00Z'),
        ),
        CreditTransactionModel.fromJson(
          _json(createdAt: '2025-06-01T00:00:00Z'),
        ),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      expect(transactions.map((t) => t.createdAt), [
        DateTime.utc(2026, 1, 2),
        DateTime.utc(2025, 6, 1),
        CreditTransactionModel.unknownCreatedAt,
      ]);
    });
  });
}
