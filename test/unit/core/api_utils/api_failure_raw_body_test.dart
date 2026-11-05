import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

ApiFailure _failureFor(int status, Object? body) {
  final options = RequestOptions(path: '/auth/login');
  return ApiFailure.fromDioException(
    DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: status,
        data: body,
      ),
      message:
          'This exception was thrown because the response has a '
          'status code of $status and RequestOptions.validateStatus was '
          'configured to throw for this status code.',
    ),
  );
}

void main() {
  group('ApiFailure with a 4xx body that is not the API error shape', () {
    test('an HTML page from a proxy is not shown', () {
      final failure = _failureFor(
        400,
        '<html><head><title>400 Bad Request</title></head>'
        '<body><center><h1>400 Bad Request</h1></center></body></html>',
      );

      expect(failure.kind, ApiFailureKind.client);
      expect(
        failure.friendlyMessage,
        "The request couldn't be completed. Please try again.",
      );
    });

    test('a rate limiter page says to wait', () {
      final failure = _failureFor(
        429,
        '<html><body>Rate limited</body></html>',
      );

      expect(
        failure.friendlyMessage,
        'Too many requests. Please wait a moment and try again.',
      );
    });

    test("Dio's status-code text is not shown either", () {
      final failure = _failureFor(409, {'status': 'error'});

      expect(failure.friendlyMessage, isNot(contains('RequestOptions')));
      expect(
        failure.friendlyMessage,
        "The request couldn't be completed. Please try again.",
      );
    });
  });

  group('ApiFailure keeps the messages the server meant for people', () {
    test('a JSON message', () {
      final failure = _failureFor(400, {'message': 'Invalid credentials'});

      expect(failure.friendlyMessage, 'Invalid credentials');
    });

    test('a short plain-text body', () {
      final failure = _failureFor(409, 'Email already exists\n');

      expect(failure.friendlyMessage, 'Email already exists');
    });
  });
}
