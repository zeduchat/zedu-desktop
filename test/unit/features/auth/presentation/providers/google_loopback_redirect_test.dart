import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('waitForLoopbackRedirect', () {
    test('gives up when the browser never comes back', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final request = await waitForLoopbackRedirect(
        server,
        timeout: const Duration(milliseconds: 50),
      );

      expect(request, isNull);
    });

    test('returns the redirect carrying the authorization code', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      final waiting = waitForLoopbackRedirect(
        server,
        timeout: const Duration(seconds: 5),
      );
      final browser = client
          .get('127.0.0.1', server.port, '/?code=abc123')
          .then((req) => req.close());
      final request = await waiting;

      expect(request?.uri.queryParameters['code'], 'abc123');
      await request!.response.close();
      await browser;
    });

    test('stops waiting when the server is closed by a new attempt', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

      final waiting = waitForLoopbackRedirect(
        server,
        timeout: const Duration(seconds: 5),
      );
      await server.close(force: true);

      expect(await waiting, isNull);
    });

    test('frees the port for a retry after timing out', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      await waitForLoopbackRedirect(
        server,
        timeout: const Duration(milliseconds: 50),
      );
      await server.close();

      final retry = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      await retry.close();
    });
  });
}
