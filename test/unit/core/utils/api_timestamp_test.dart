import '../../../helpers/helpers.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('parseApiTimestamp', () {
    test('parses epoch seconds encoded as a string', () {
      expect(
        parseApiTimestamp('1700000000'),
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
      );
    });

    test('parses epoch seconds encoded as a number', () {
      expect(
        parseApiTimestamp(1700000000),
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
      );
    });

    test('parses ISO-8601 strings', () {
      expect(
        parseApiTimestamp('2023-11-14T22:13:20.000Z'),
        DateTime.utc(2023, 11, 14, 22, 13, 20),
      );
    });

    test('parses ISO-8601 strings without a timezone', () {
      expect(
        parseApiTimestamp('2023-11-14T22:13:20'),
        DateTime(2023, 11, 14, 22, 13, 20),
      );
    });

    test('names the field when the value is missing', () {
      expect(
        () => parseApiTimestamp(null, field: 'created_at'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Missing created_at',
          ),
        ),
      );
    });

    test('names the field when the value is not a timestamp', () {
      expect(
        () => parseApiTimestamp('not-a-date', field: 'updated_at'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Unrecognised updated_at: not-a-date',
          ),
        ),
      );
    });
  });
}
