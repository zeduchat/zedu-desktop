import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('UserProfileRemoteDataSourceImpl.inviteMember role payload', () {
    test('sends the resolved role id as role_id and the org id', () async {
      final captured = await _captureInvite(
        invitations: _confirmedInvite,
        roleName: null,
      );

      final body = captured.data as Map<String, dynamic>;
      expect(body['role_id'], equals('role-manager'));
      expect(body['org_id'], equals('org-1'));
      expect(body['emails'], equals(['invitee@example.com']));
    });

    test('prefers the backend role_name when the response echoes it', () async {
      final member = await _invite(
        invitations: const [
          {
            'id': 'invite-1',
            'email': 'invitee@example.com',
            'role_name': 'Manager',
            'sent_at': '2026-01-01',
          },
        ],
      );

      expect(member.role, equals('Manager'));
      expect(
        member.role,
        isNot(equals('role-manager')),
        reason: 'the backend role name wins over the raw UUID',
      );
    });

    test(
      'falls back to the requested role id when no role_name is returned',
      () async {
        final member = await _invite(
          invitations: const [
            {
              'id': 'invite-1',
              'email': 'invitee@example.com',
              'sent_at': '2026-01-01',
            },
          ],
        );

        expect(member.role, equals('role-manager'));
      },
    );
  });

  group(
    'UserProfileRemoteDataSourceImpl.inviteMember Referer (Ziki #2708)',
    () {
      test(
        'sends the web app address so the emailed link has a host',
        () async {
          final captured = await _captureInvite(
            invitations: _confirmedInvite,
            roleName: null,
          );

          // zedu-be builds the link as Referer + 'accept_org_invitation?...'.
          expect(captured.headers['Referer'], 'https://example.com/');
        },
      );

      test('uses WEB_APP_URL when it is set', () async {
        final captured = await _captureInvite(
          invitations: _confirmedInvite,
          roleName: null,
          webAppUrl: 'https://app.zedu.chat',
        );

        expect(captured.headers['Referer'], 'https://app.zedu.chat/');
      });
    },
  );
}

/// The server confirms the invitation; without one, inviteMember throws.
const _confirmedInvite = [
  {'id': 'invite-1', 'email': 'invitee@example.com'},
];

Future<RequestOptions> _captureInvite({
  required List<dynamic> invitations,
  required String? roleName,
  String webAppUrl = '',
}) async {
  final config = AppConfig(
    apiBaseUrl: 'https://api.example.com/api/v1/',
    usesMockData: false,
    webAppUrl: webAppUrl,
  );
  final dio = Dio();
  RequestOptions? captured;
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        captured = options;
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            data: {
              'data': {'invitations': invitations},
            },
          ),
        );
      },
    ),
  );

  final dataSource = UserProfileRemoteDataSourceImpl(
    config: config,
    apiBaseService: ApiBaseService(config: config, dio: dio),
  );

  await dataSource.inviteMember(
    email: 'invitee@example.com',
    role: 'role-manager',
    orgId: 'org-1',
  );

  return captured!;
}

Future<TeamMember> _invite({required List<dynamic> invitations}) async {
  final config = AppConfig(
    apiBaseUrl: 'https://api.example.com/api/v1/',
    usesMockData: false,
  );
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            data: {
              'data': {'invitations': invitations},
            },
          ),
        );
      },
    ),
  );

  final dataSource = UserProfileRemoteDataSourceImpl(
    config: config,
    apiBaseService: ApiBaseService(config: config, dio: dio),
  );

  return dataSource.inviteMember(
    email: 'invitee@example.com',
    role: 'role-manager',
    orgId: 'org-1',
  );
}
