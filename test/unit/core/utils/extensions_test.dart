import 'package:zedu/core/core.dart';

import '../../../helpers/helpers.dart';

void main() {
  group('CountLabelX.countLabel', () {
    test('uses the singular for one', () {
      expect(1.countLabel('member'), '1 member');
    });

    test('uses the plural for zero and more than one', () {
      expect(0.countLabel('member'), '0 members');
      expect(5.countLabel('member'), '5 members');
    });

    test('uses an irregular plural when given', () {
      expect(2.countLabel('person', 'people'), '2 people');
      expect(1.countLabel('person', 'people'), '1 person');
    });
  });
}
