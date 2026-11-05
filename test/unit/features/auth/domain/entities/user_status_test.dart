import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('StatusTimeout.expiryFrom', () {
    group('this week ends at 23:59:59 on the coming Sunday', () {
      // 2 Nov 2026 is a Monday, so 2-8 Nov covers Monday to Sunday.
      final weekEnd = DateTime(2026, 11, 8, 23, 59, 59);
      final cases = <String, DateTime>{
        'Monday': DateTime(2026, 11, 2, 9, 15),
        'Tuesday': DateTime(2026, 11, 3, 0, 0),
        'Wednesday': DateTime(2026, 11, 4, 12, 30),
        'Thursday': DateTime(2026, 11, 5, 18, 40),
        'Friday': DateTime(2026, 11, 6, 8, 5),
        'Saturday': DateTime(2026, 11, 7, 23, 59, 59),
      };

      cases.forEach((day, now) {
        test('when set on a $day', () {
          expect(now.weekday, isNot(DateTime.sunday));
          expect(StatusTimeout.thisWeek.expiryFrom(now), weekEnd);
        });
      });

      test('when set on a Sunday, it runs to the next Sunday', () {
        final sunday = DateTime(2026, 11, 8, 14, 30);

        expect(sunday.weekday, DateTime.sunday);
        expect(
          StatusTimeout.thisWeek.expiryFrom(sunday),
          DateTime(2026, 11, 15, 23, 59, 59),
        );
      });
    });

    test('this week rolls over the end of the month', () {
      final friday = DateTime(2026, 10, 30, 8);

      expect(
        StatusTimeout.thisWeek.expiryFrom(friday),
        DateTime(2026, 11, 1, 23, 59, 59),
      );
    });

    test('other timeouts keep their expiry', () {
      final now = DateTime(2026, 11, 4, 10);

      expect(
        StatusTimeout.thirtyMinutes.expiryFrom(now),
        DateTime(2026, 11, 4, 10, 30),
      );
      expect(StatusTimeout.oneHour.expiryFrom(now), DateTime(2026, 11, 4, 11));
      expect(
        StatusTimeout.today.expiryFrom(now),
        DateTime(2026, 11, 4, 23, 59),
      );
      expect(StatusTimeout.dontRemove.expiryFrom(now), isNull);
    });
  });
}
