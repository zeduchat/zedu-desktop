import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  AccelSample sample(double x, double y, double z, DateTime t) =>
      AccelSample(x, y, z, t);

  final start = DateTime(2026, 1, 1);

  group('ShakeDetector', () {
    test('ignores steady gravity', () {
      final detector = ShakeDetector();
      expect(detector.feed(sample(0, 0, 9.81, start)), isFalse);
      expect(
        detector.feed(
          sample(0, 0, 9.81, start.add(const Duration(milliseconds: 20))),
        ),
        isFalse,
      );
    });

    test('a single jerk is not a shake', () {
      final detector = ShakeDetector();
      detector.feed(sample(0, 0, 9.81, start));
      expect(
        detector.feed(
          sample(0, 0, 40, start.add(const Duration(milliseconds: 20))),
        ),
        isFalse,
      );
    });

    test('two jerks inside the burst window are a shake', () {
      final detector = ShakeDetector();
      detector.feed(sample(0, 0, 9.81, start));
      expect(
        detector.feed(
          sample(0, 0, 40, start.add(const Duration(milliseconds: 20))),
        ),
        isFalse,
      );
      expect(
        detector.feed(
          sample(0, 0, 60, start.add(const Duration(milliseconds: 60))),
        ),
        isTrue,
      );
    });

    test('cooldown suppresses a second shake', () {
      final detector = ShakeDetector();
      detector.feed(sample(0, 0, 9.81, start));
      detector.feed(
        sample(0, 0, 40, start.add(const Duration(milliseconds: 20))),
      );
      expect(
        detector.feed(
          sample(0, 0, 60, start.add(const Duration(milliseconds: 60))),
        ),
        isTrue,
      );

      final after = start.add(const Duration(milliseconds: 100));
      detector.feed(sample(0, 0, 9.81, after));
      detector.feed(
        sample(0, 0, 45, after.add(const Duration(milliseconds: 20))),
      );
      expect(
        detector.feed(
          sample(0, 0, 65, after.add(const Duration(milliseconds: 60))),
        ),
        isFalse,
      );
    });

    test('shakes again after the cooldown', () {
      final detector = ShakeDetector(
        cooldown: const Duration(milliseconds: 500),
      );
      detector.feed(sample(0, 0, 9.81, start));
      detector.feed(
        sample(0, 0, 40, start.add(const Duration(milliseconds: 20))),
      );
      expect(
        detector.feed(
          sample(0, 0, 60, start.add(const Duration(milliseconds: 60))),
        ),
        isTrue,
      );

      final after = start.add(const Duration(seconds: 1));
      detector.feed(sample(0, 0, 9.81, after));
      expect(
        detector.feed(
          sample(0, 0, 40, after.add(const Duration(milliseconds: 20))),
        ),
        isTrue,
      );
    });
  });
}
