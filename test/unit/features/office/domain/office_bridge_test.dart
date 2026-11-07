import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  const officeUrl = 'https://office.example.com';
  const apiUrl = 'https://api.example.com/api/v1/';

  late int exits;
  late String? token;
  late OfficeBridge bridge;

  setUp(() {
    exits = 0;
    token = 'zedu-token';
    bridge = OfficeBridge(
      officeUrl: officeUrl,
      apiUrl: apiUrl,
      readToken: () async => token,
      onExit: () => exits++,
    );
  });

  final officePage = Uri.parse('$officeUrl/auth/desktop');

  group('getZeduToken', () {
    test('hands the zedu session to an Office page', () async {
      final reply = await bridge.handle([
        {'type': 'getZeduToken'},
      ], officePage);

      expect(reply, {'token': 'zedu-token', 'apiUrl': apiUrl});
    });

    test('refuses a page on another origin', () async {
      for (final page in [
        Uri.parse('https://elsewhere.example.com/auth/desktop'),
        Uri.parse('http://office.example.com/auth/desktop'),
        Uri.parse('https://office.example.com:8443/auth/desktop'),
        null,
      ]) {
        final reply = await bridge.handle([
          {'type': 'getZeduToken'},
        ], page);
        expect(reply, isNull, reason: '$page must not get the session');
      }
    });

    test('answers nothing when signed out', () async {
      token = null;
      final reply = await bridge.handle([
        {'type': 'getZeduToken'},
      ], officePage);

      expect(reply, isNull);
    });
  });

  test('exit closes Office', () async {
    final reply = await bridge.handle([
      {'type': 'exit'},
    ], officePage);

    expect(reply, isNull);
    expect(exits, 1);
  });

  test('ignores unknown or malformed messages', () async {
    for (final args in <List<dynamic>>[
      [],
      ['exit'],
      [
        {'type': 'somethingElse'},
      ],
    ]) {
      expect(await bridge.handle(args, officePage), isNull);
    }
    expect(exits, 0);
  });
}
