import 'dart:io';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../helpers/helpers.dart';

class _MockApi extends Mock implements ApiBaseService {}

void main() {
  group('profilePhotoFileName', () {
    test('takes the name from a Windows path', () {
      expect(profilePhotoFileName(r'C:\Users\ada\Pictures\me.png'), 'me.png');
    });

    test('takes the name from a POSIX path', () {
      expect(profilePhotoFileName('/home/ada/Pictures/me.jpg'), 'me.jpg');
    });
  });

  group('profile photo requests', () {
    late _MockApi api;
    late UserProfileRemoteDataSourceImpl datasource;
    late Directory dir;

    setUp(() {
      api = _MockApi();
      datasource = UserProfileRemoteDataSourceImpl(
        config: const AppConfig(apiBaseUrl: '', usesMockData: false),
        apiBaseService: api,
      );
      dir = Directory.systemTemp.createTempSync('profile_photo_');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('uploads the photo as avatar_file on PATCH /profile', () async {
      final file = File('${dir.path}${Platform.pathSeparator}me.png')
        ..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);
      when(
        () => api.patch<Map<String, dynamic>>(
          path: any(named: 'path'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async =>
            ApiResponseModel<Map<String, dynamic>>(data: {}, statusCode: 200),
      );

      await datasource.uploadAvatar(file.path);

      final captured = verify(
        () => api.patch<Map<String, dynamic>>(
          path: '/profile',
          data: captureAny(named: 'data'),
        ),
      ).captured;
      final form = captured.single as FormData;
      final photo = form.files.single;
      expect(photo.key, 'avatar_file');
      expect(photo.value.filename, 'me.png');
      expect(photo.value.contentType?.mimeType, 'image/png');
    });

    test('removes the photo with DELETE /profile/image', () async {
      when(
        () => api.delete<Map<String, dynamic>>(path: any(named: 'path')),
      ).thenAnswer(
        (_) async =>
            ApiResponseModel<Map<String, dynamic>>(data: {}, statusCode: 200),
      );

      await datasource.removeAvatar();

      verify(
        () => api.delete<Map<String, dynamic>>(path: '/profile/image'),
      ).called(1);
    });
  });
}
