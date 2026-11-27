import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/mock/mock.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('mockLoginResponse', () {
    final serialized = jsonEncode(mockLoginResponse);

    test('contains no JWT-shaped string', () {
      expect(serialized.contains('eyJ'), isFalse);
    });

    test('uses only example.com email addresses', () {
      final emails = RegExp(
        r'[\w.+-]+@[\w.+-]+',
      ).allMatches(serialized).map((m) => m.group(0)!).toList();

      expect(emails, isNotEmpty);
      for (final email in emails) {
        expect(email, endsWith('@example.com'));
      }
    });

    test('uses placeholder credentials', () {
      expect(mockLoginResponse['access_token'], 'mock-access-token');
      expect(
        mockLoginResponse['notification_token'],
        'mock-notification-token',
      );
    });

    test('still parses into a LoginResponseModel', () {
      final response = LoginResponseModel.fromJson(mockLoginResponse);

      expect(response.accessToken, 'mock-access-token');
      expect(response.user.email, 'mock.user@example.com');
      expect(response.user.username, 'mockuser');
    });
  });
}
