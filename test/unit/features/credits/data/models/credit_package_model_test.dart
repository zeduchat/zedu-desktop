import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('CreditPackageModel.fromJson', () {
    test('parses numeric price and credits', () {
      final model = CreditPackageModel.fromJson({
        'id': 'pkg-1',
        'name': 'Starter',
        'description': 'A starter package',
        'price': 1900,
        'credits': 500,
        'benefits': ['Unlimited calls', 'Priority support'],
        'plan_slug': 'starter',
      });

      expect(model.id, 'pkg-1');
      expect(model.name, 'Starter');
      expect(model.price, 1900);
      expect(model.credits, 500);
      expect(model.benefits, ['Unlimited calls', 'Priority support']);
      expect(model.planSlug, 'starter');
    });

    test('parses string-encoded price and credits', () {
      final model = CreditPackageModel.fromJson({
        'id': 'pkg-2',
        'name': 'Growth',
        'description': 'A growth package',
        'price': '1900',
        'credits': '500',
      });

      expect(model.price, 1900);
      expect(model.credits, 500);
    });

    test('truncates decimal strings and accepts numeric strings', () {
      final model = CreditPackageModel.fromJson({
        'price': '1900.75',
        'credits': ' 500 ',
      });

      expect(model.price, 1900);
      expect(model.credits, 500);
    });

    test('falls back to zero for missing or invalid values', () {
      final missing = CreditPackageModel.fromJson({'id': 'pkg-3'});
      final invalid = CreditPackageModel.fromJson({
        'price': 'not a price',
        'credits': <String, dynamic>{},
      });

      expect(missing.price, 0);
      expect(missing.credits, 0);
      expect(invalid.price, 0);
      expect(invalid.credits, 0);
    });

    test('reads the slug fallback when plan_slug is absent', () {
      final model = CreditPackageModel.fromJson({'slug': 'legacy'});

      expect(model.planSlug, 'legacy');
    });
  });
}
