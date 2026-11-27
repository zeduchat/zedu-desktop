import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class _MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late _MockApiBaseService api;
  late WorkspaceRemoteDataSourceImpl datasource;

  setUp(() {
    api = _MockApiBaseService();
    datasource = WorkspaceRemoteDataSourceImpl(apiBaseService: api);
  });

  void stubResponse(Map<String, dynamic> body) {
    when(
      () => api.get<Map<String, dynamic>>(path: '/users/organisations'),
    ).thenAnswer((_) async => ApiResponseModel(data: body, statusCode: 200));
  }

  group('WorkspaceRemoteDataSourceImpl.getOrganisations', () {
    test('reads GET /users/organisations into workspaces', () async {
      stubResponse({
        'data': [
          {
            'id': ' org-1 ',
            'name': 'HNG',
            'logo_url': 'https://example.invalid/logo.png',
            'Users': [
              <String, dynamic>{},
              <String, dynamic>{},
              <String, dynamic>{},
            ],
          },
          {'id': 42},
        ],
      });

      final workspaces = await datasource.getOrganisations();

      verify(
        () => api.get<Map<String, dynamic>>(path: '/users/organisations'),
      ).called(1);
      expect(workspaces, hasLength(2));
      expect(workspaces[0].id, 'org-1');
      expect(workspaces[0].name, 'HNG');
      expect(workspaces[0].avatar, 'https://example.invalid/logo.png');
      expect(workspaces[0].membersCount, 3);
      expect(workspaces[1].id, '42');
      expect(workspaces[1].name, 'Workspace');
      expect(workspaces[1].avatar, '');
      expect(workspaces[1].membersCount, 0);
    });

    test('skips organisations without an id and non-map items', () async {
      stubResponse({
        'data': [
          {'id': '', 'name': 'Blank'},
          {'name': 'Missing'},
          'not a map',
          {'id': 'org-2', 'name': 'Kept'},
        ],
      });

      final workspaces = await datasource.getOrganisations();

      expect(workspaces.map((w) => w.id), ['org-2']);
    });

    test('a missing data list returns no workspaces', () async {
      stubResponse(<String, dynamic>{});

      expect(await datasource.getOrganisations(), isEmpty);
    });

    test('a data value that is not a list throws', () async {
      stubResponse({
        'data': {'id': 'org-1'},
      });

      expect(datasource.getOrganisations(), throwsA(isA<TypeError>()));
    });

    test('a failed request is passed on', () async {
      when(
        () => api.get<Map<String, dynamic>>(path: '/users/organisations'),
      ).thenThrow(const ApiFailure(message: 'down'));

      expect(datasource.getOrganisations(), throwsA(isA<ApiFailure>()));
    });
  });
}
