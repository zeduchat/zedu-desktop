import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/auth/data/models/organisation_model.dart';
import 'package:zedu/features/auth/data/models/plan_details_model.dart';

void main() {
  group('PlanDetailsModel.fromJson dates', () {
    final noDate = DateTime.utc(1);

    test('reads valid ISO-8601 dates', () {
      final model = PlanDetailsModel.fromJson(const {
        'created_at': '2026-01-01T12:00:00Z',
        'updated_at': '2026-01-02T12:00:00Z',
      });

      expect(model.createdAt, DateTime.utc(2026, 1, 1, 12));
      expect(model.updatedAt, DateTime.utc(2026, 1, 2, 12));
    });

    test('uses the same fallback when the dates are missing', () {
      final model = PlanDetailsModel.fromJson(const {});

      expect(model.createdAt, noDate);
      expect(model.updatedAt, noDate);
    });

    for (final value in <Object?>[null, '', 'not-a-date', 42]) {
      test('falls back without throwing for ${value.runtimeType} "$value"', () {
        final model = PlanDetailsModel.fromJson({
          'created_at': value,
          'updated_at': value,
        });

        expect(model.createdAt, noDate);
        expect(model.updatedAt, noDate);
      });
    }

    test('one good date is kept when the other is unreadable', () {
      final model = PlanDetailsModel.fromJson(const {
        'created_at': '',
        'updated_at': '2026-01-02T12:00:00Z',
      });

      expect(model.createdAt, noDate);
      expect(model.updatedAt, DateTime.utc(2026, 1, 2, 12));
    });

    test('a bad plan date does not stop an organisation from parsing', () {
      final model = OrganisationModel.fromJson(const {
        'organisation_plan': {
          'plan_details': {'name': 'Pro Plan', 'created_at': ''},
        },
      });

      expect(model.organisationPlan.planDetails.name, 'Pro Plan');
    });
  });
}
