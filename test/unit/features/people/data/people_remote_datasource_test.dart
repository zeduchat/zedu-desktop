import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late PeopleRemoteDataSourceImpl datasource;

  setUp(() {
    api = MockApiBaseService();
    datasource = PeopleRemoteDataSourceImpl(apiBaseService: api);
  });

  void answer(Map<String, dynamic> query, Map<String, dynamic> body) {
    when(
      () => api.get<Map<String, dynamic>>(
        path: '/organisations/org-1/users',
        queryParameters: query,
      ),
    ).thenAnswer(
      (_) async =>
          ApiResponseModel<Map<String, dynamic>>(statusCode: 200, data: body),
    );
  }

  test('asks for a page of 50 with the search and reads members', () async {
    answer(
      {'page': 2, 'limit': 50, 'search': 'ada'},
      {
        'data': [
          {
            'id': 'u-1',
            'name': 'Ada Lovelace',
            'email': 'ada@zedu.test',
            'phone_number': '+234 800',
            'avatar_url': '',
            'default_avatar_url': 'https://cdn.zedu.test/a.png',
            'online': true,
          },
          {'user_id': 'u-2', 'username': 'grace', 'is_deactivated': 'true'},
          {'name': 'No id'},
        ],
        'pagination': {'current_page': 2, 'total_pages': 3, 'total_items': 120},
      },
    );

    final page = await datasource.fetchMembers(
      orgId: 'org-1',
      page: 2,
      search: ' ada ',
    );

    expect(page.members.map((m) => m.id), ['u-1', 'u-2']);
    final ada = page.members.first;
    expect(ada.displayName, 'Ada Lovelace');
    expect(ada.phone, '+234 800');
    expect(ada.photoUrl, 'https://cdn.zedu.test/a.png');
    expect(ada.online, isTrue);
    expect(page.members.last.displayName, 'grace');
    expect(page.members.last.deactivated, isTrue);
    expect(page.currentPage, 2);
    expect(page.totalPages, 3);
    expect(page.totalItems, 120);
    expect(page.hasMore, isTrue);
  });

  test('reads pagination sent as a list', () async {
    answer(
      {'page': 1, 'limit': 50},
      {
        'data': [
          {'id': 'u-1', 'name': 'Ada'},
        ],
        'pagination': [
          {'current_page': 1, 'total_pages': 1, 'total_items': 1},
        ],
      },
    );

    final page = await datasource.fetchMembers(orgId: 'org-1');

    expect(page.totalItems, 1);
    expect(page.hasMore, isFalse);
  });

  test('without pagination a full page means there may be more', () async {
    answer(
      {'page': 1, 'limit': 50},
      {
        'data': [
          for (var i = 0; i < 50; i++) {'id': 'u-$i'},
        ],
      },
    );

    final page = await datasource.fetchMembers(orgId: 'org-1');

    expect(page.hasMore, isTrue);
    expect(page.totalItems, 50);
  });
}
