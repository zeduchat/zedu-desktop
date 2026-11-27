import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockApiBaseService extends Mock implements ApiBaseService {}

void main() {
  late MockApiBaseService api;
  late UserProfileRemoteDataSourceImpl datasource;

  setUp(() {
    api = MockApiBaseService();
    datasource = UserProfileRemoteDataSourceImpl(
      config: const AppConfig(apiBaseUrl: '', usesMockData: false),
      apiBaseService: api,
    );
  });

  group('UserProfileRemoteDataSourceImpl profile photo (Ziki #12421)', () {
    test('uploads the photo as avatar_file on PATCH /profile, '
        'with no other fields', () async {
      when(
        () => api.patch<Map<String, dynamic>>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: {'data': <String, dynamic>{}},
        ),
      );
      final dir = await Directory.systemTemp.createTemp('avatar_test');
      addTearDown(() => dir.delete(recursive: true));
      final photo = File('${dir.path}${Platform.pathSeparator}me.png')
        ..writeAsBytesSync([137, 80, 78, 71]);

      await datasource.uploadAvatar(photo.path);

      final data =
          verify(
                () => api.patch<Map<String, dynamic>>(
                  path: '/profile',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as FormData;
      expect(data.fields, isEmpty);
      expect(data.files.single.key, 'avatar_file');
      expect(data.files.single.value.filename, 'me.png');
    });

    test('removes the photo with DELETE /profile/image', () async {
      when(
        () => api.delete<Map<String, dynamic>>(path: '/profile/image'),
      ).thenAnswer(
        (_) async => const ApiResponseModel<Map<String, dynamic>>(
          statusCode: 200,
          data: <String, dynamic>{},
        ),
      );

      await datasource.removeAvatar();

      verify(
        () => api.delete<Map<String, dynamic>>(path: '/profile/image'),
      ).called(1);
    });
  });
}
