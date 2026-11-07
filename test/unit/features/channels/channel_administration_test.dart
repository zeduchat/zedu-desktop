import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  test('administration permissions fail closed', () {
    expect(canAdministerChannels({}), isFalse);
    expect(canAdministerChannels({'role': 'guest'}), isFalse);
    expect(
      canAdministerChannels({
        'user_role': {'role_name': 'Administrator'},
      }),
      isTrue,
    );
    expect(
      canAdministerChannels({
        'user_role': {
          'role_name': 'Custom',
          'permissions': ['can_manage_channels'],
        },
      }),
      isTrue,
    );
  });
  test('missing metadata remains unavailable', () {
    final item = ManagedChannel.fromJson({'id': 'c1', 'name': 'general'});
    expect(item.createdAt, isNull);
    expect(item.memberCount, isNull);
    expect(ManagedChannel.fromJson({'user_count': 0}).memberCount, 0);
  });
}
