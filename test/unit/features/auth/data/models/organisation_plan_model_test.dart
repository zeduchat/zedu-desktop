import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/auth/data/models/organisation_model.dart';
import 'package:zedu/features/auth/data/models/organisation_plan_model.dart';

void main() {
  group('OrganisationPlanModel.fromJson plan_details', () {
    test('reads a valid plan_details map', () {
      final model = OrganisationPlanModel.fromJson(const {
        'plan_details': {'name': 'Pro Plan', 'max_users': 25},
      });

      expect(model.planDetails.name, 'Pro Plan');
      expect(model.planDetails.maxUsers, 25);
    });

    test('uses empty plan details when plan_details is missing', () {
      final model = OrganisationPlanModel.fromJson(const {});

      expect(model.planDetails.name, '');
      expect(model.planDetails.maxUsers, 0);
    });

    for (final value in <Object?>[null, 'free', 42, <dynamic>[]]) {
      test('uses empty plan details for ${value.runtimeType} "$value"', () {
        final model = OrganisationPlanModel.fromJson({'plan_details': value});

        expect(model.planDetails.name, '');
        expect(model.planDetails.aiCreditsPurchasable, isFalse);
      });
    }

    test('keeps the plan dates when plan_details is null', () {
      final model = OrganisationPlanModel.fromJson(const {
        'started_at': '2026-01-01T00:00:00Z',
        'plan_details': null,
      });

      expect(model.startedAt, DateTime.utc(2026));
    });

    test('an organisation with null plan_details still parses', () {
      final model = OrganisationModel.fromJson(const {
        'id': 'org-1',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
        'organisation_plan': {'plan_details': null},
      });

      expect(model.id, 'org-1');
      expect(model.organisationPlan.planDetails.name, '');
    });
  });
}
