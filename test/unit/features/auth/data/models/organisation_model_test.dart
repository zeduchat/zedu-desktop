import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/auth/data/models/organisation_model.dart';

void main() {
  group('OrganisationModel.fromJson', () {
    test('deserializes completely with standard valid payload', () {
      final json = <String, dynamic>{
        'id': 'org-123',
        'name': 'Acme Corp',
        'description': 'A test org',
        'email': 'acme@example.com',
        'type': 'company',
        'location': 'New York',
        'country': 'USA',
        'owner_id': 'user-1',
        'logo_url': 'https://example.com/logo.png',
        'credit_balance': 100,
        'channels_count': 5,
        'total_messages_count': 500,
        'org_roles': ['admin', 'member'],
        'pinned': true,
        'Users': null,
        'created_at': '2026-01-01T12:00:00Z',
        'updated_at': '2026-01-02T12:00:00Z',
        'channels': null,
        'subscription_plan_id': 'sub-99',
        'stripe_customer_id': 'cus_12345',
        'org_plan_id': 'plan-55',
        'organisation_plan': {
          'started_at': '2026-01-01T00:00:00Z',
          'ended_at': '2026-12-31T00:00:00Z',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
          'plan_details': {
            'id': 'pd-1',
            'name': 'Pro Plan',
            'description': 'Full features',
            'fee': 10,
            'max_channels': 100,
            'max_users': 50,
            'max_notifications': 1000,
            'credits': 500,
          },
        },
        'organisation_slug': 'acme-corp',
        'user_role': {'role_id': 'role-owner', 'role_name': 'Owner'},
      };

      final model = OrganisationModel.fromJson(json);

      expect(model.id, 'org-123');
      expect(model.name, 'Acme Corp');
      expect(model.description, 'A test org');
      expect(model.email, 'acme@example.com');
      expect(model.logoUrl, 'https://example.com/logo.png');
      expect(model.stripeCustomerId, 'cus_12345');
      expect(model.subscriptionPlanId, 'sub-99');
      expect(model.orgPlanId, 'plan-55');
      expect(model.creditBalance, 100);
      expect(model.pinned, true);
      expect(model.userRole.roleName, 'Owner');
    });

    test(
      'handles null description, logo_url, and stripe_customer_id gracefully without throwing',
      () {
        final json = <String, dynamic>{
          'id': 'org-456',
          'name': 'No Metadata Corp',
          'description': null,
          'email': null,
          'type': null,
          'location': null,
          'country': null,
          'owner_id': 'user-2',
          'logo_url': null,
          'credit_balance': null,
          'channels_count': null,
          'total_messages_count': null,
          'org_roles': null,
          'pinned': null,
          'Users': null,
          'created_at': null,
          'updated_at': null,
          'channels': null,
          'subscription_plan_id': null,
          'stripe_customer_id': null,
          'org_plan_id': null,
          'organisation_plan': null,
          'organisation_slug': null,
          'user_role': null,
        };

        expect(() => OrganisationModel.fromJson(json), returnsNormally);

        final model = OrganisationModel.fromJson(json);
        expect(model.id, 'org-456');
        expect(model.name, 'No Metadata Corp');
        expect(model.description, '');
        expect(model.email, '');
        expect(model.type, '');
        expect(model.location, '');
        expect(model.country, '');
        expect(model.logoUrl, '');
        expect(model.stripeCustomerId, '');
        expect(model.subscriptionPlanId, '');
        expect(model.orgPlanId, '');
        expect(model.creditBalance, 0);
        expect(model.channelsCount, 0);
        expect(model.totalMessagesCount, 0);
        expect(model.orgRoles, isEmpty);
        expect(model.pinned, false);
        expect(model.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
        expect(model.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
        expect(model.organisationSlug, '');
        expect(model.userRole.roleId, '');
        expect(model.userRole.roleName, '');
      },
    );

    test('handles malformed date strings gracefully with epoch fallback', () {
      final json = <String, dynamic>{
        'id': 'org-789',
        'name': 'Bad Dates Corp',
        'created_at': 'invalid-date',
        'updated_at': 'not-a-timestamp',
      };

      final model = OrganisationModel.fromJson(json);
      expect(model.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(model.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });
}
