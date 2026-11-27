import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

Future<RequestOptions> _send(ProfileAvatarChange change) async {
  final config = AppConfig(
    apiBaseUrl: 'https://api.example.com/api/v1/',
    usesMockData: false,
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
            data: {'status': 'success'},
          ),
        );
      },
    ),
  );
  final dataSource = UserProfileRemoteDataSourceImpl(
    config: config,
    apiBaseService: ApiBaseService(config: config, dio: dio),
  );
  await dataSource.updateAvatar(change);
  return captured!;
}

void main() {
  group('UserProfileRemoteDataSourceImpl.updateAvatar', () {
    test('PATCHes /profile with the image as avatar_file', () async {
      final bytes = Uint8List.fromList([137, 80, 78, 71]);
      final request = await _send(
        ProfileAvatarChange.upload(bytes: bytes, fileName: 'me.png'),
      );

      expect(request.method, 'PATCH');
      expect(request.path, endsWith('profile'));
      final form = request.data as FormData;
      expect(form.fields, isEmpty);
      final file = form.files.single;
      expect(file.key, 'avatar_file');
      expect(file.value.filename, 'me.png');
      expect(file.value.length, bytes.length);
      // zedu-be drops a part that is not image/png or image/jpeg.
      expect(file.value.contentType.toString(), 'image/png');
    });

    test('labels a JPEG as image/jpeg', () async {
      final request = await _send(
        ProfileAvatarChange.upload(
          bytes: Uint8List.fromList([255, 216, 255]),
          fileName: 'me.JPG',
        ),
      );

      final file = (request.data as FormData).files.single;
      expect(file.value.contentType.toString(), 'image/jpeg');
    });

    test('removes the photo with DELETE /profile/image', () async {
      final request = await _send(const ProfileAvatarChange.remove());

      expect(request.method, 'DELETE');
      expect(request.path, endsWith('profile/image'));
    });
  });
}
