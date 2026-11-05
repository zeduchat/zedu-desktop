import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  group('ConnectionTokenModel', () {
    test('parses a valid token payload', () {
      final model = ConnectionTokenModel.fromJson({'token': 'abc.def.ghi'});

      expect(model.token, 'abc.def.ghi');
    });

    test('falls back to an empty token when the field is missing', () {
      final model = ConnectionTokenModel.fromJson(const {});

      expect(model.token, isEmpty);
    });

    test('round-trips through toJson', () {
      const original = ConnectionTokenModel(token: 'abc.def.ghi');

      expect(
        ConnectionTokenModel.fromJson(original.toJson()).token,
        original.token,
      );
    });
  });
}
