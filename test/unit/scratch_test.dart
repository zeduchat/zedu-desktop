import 'package:flutter_test/flutter_test.dart';

sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

class Failure<T> extends Result<T> {
  const Failure(this.error);
  final String error;
}

class ProfileAccount {}

class ProfileAccountModel extends ProfileAccount {}

T? valueOrNull<T>(Result<T> result) {
  return switch (result) {
    Success<T>() => result.value,
    Failure<T>() => null,
  };
}

void main() {
  test('valueOrNull test with model type', () {
    try {
      Result<dynamic> result = Failure<ProfileAccountModel>('error');
      final castedResult = result as Result<ProfileAccount>;
      final val = valueOrNull(castedResult);
      expect(val, null);

      Result<dynamic> successResult = Success<ProfileAccountModel>(
        ProfileAccountModel(),
      );
      final castedSuccess = successResult as Result<ProfileAccount>;
      final val2 = valueOrNull(castedSuccess);
      expect(val2, isNotNull);
    } catch (e) {
      fail('Failed: $e');
    }
  });
}
