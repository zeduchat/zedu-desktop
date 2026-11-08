import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('CreditTransactionModel.fromJson', () {
    test('parses a valid transaction payload', () {
      final model = CreditTransactionModel.fromJson({
        'id': 'tx-1',
        'amount': 1900,
        'credits': 500,
        'status': 'completed',
        'created_at': '2026-11-04T07:30:00.000Z',
      });

      expect(model.id, 'tx-1');
      expect(model.amount, 1900);
      expect(model.credits, 500);
      expect(model.status, 'completed');
      expect(model.createdAt, DateTime.utc(2026, 11, 4, 7, 30));
    });

    test('uses a fixed epoch for an unparseable date', () {
      final model = CreditTransactionModel.fromJson({
        'id': 'tx-2',
        'created_at': 'not a date',
      });

      expect(
        model.createdAt,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      expect(model.createdAt.isUtc, isTrue);
    });

    test('uses the same fixed epoch for a missing date', () {
      final model = CreditTransactionModel.fromJson({'id': 'tx-3'});

      expect(
        model.createdAt,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    });

    test('unparseable dates sort to the end of a newest-first list', () {
      final valid = CreditTransactionModel.fromJson({
        'id': 'tx-4',
        'created_at': '2026-11-04T07:30:00.000Z',
      });
      final missing = CreditTransactionModel.fromJson({'id': 'tx-5'});
      final invalid = CreditTransactionModel.fromJson({
        'id': 'tx-6',
        'created_at': 'not a date',
      });

      final sorted = [missing, valid, invalid]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      expect(sorted.map((t) => t.id), ['tx-4', 'tx-5', 'tx-6']);
    });

    test('falls back for missing optional fields', () {
      final model = CreditTransactionModel.fromJson({'id': 'tx-7'});

      expect(model.amount, 0);
      expect(model.credits, 0);
      expect(model.status, 'completed');
    });
  });
}
