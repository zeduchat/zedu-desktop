import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/mock/mock.dart';

void main() {
  group('mockCredentials', () {
    test('mockPassword is const immutable string with expected value', () {
      expect(mockPassword, 'password123');
      // Verify identity and compile-time const nature
      const expected = 'password123';
      expect(identical(mockPassword, expected), isTrue);
    });
  });
}
