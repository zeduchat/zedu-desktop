import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';

void main() {
  testWidgets('fires the shake response when the device is shaken', (
    tester,
  ) async {
    final samples = StreamController<AccelSample>();
    addTearDown(samples.close);
    var shakes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ShakeToReportListener(
          samples: samples.stream,
          onShake: () => shakes++,
          child: const Scaffold(body: SizedBox()),
        ),
      ),
    );

    final start = DateTime(2026, 1, 1);
    samples.add(AccelSample(0, 0, 9.81, start));
    samples.add(
      AccelSample(0, 0, 40, start.add(const Duration(milliseconds: 20))),
    );
    samples.add(
      AccelSample(0, 0, 60, start.add(const Duration(milliseconds: 60))),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(shakes, 1);
  });

  testWidgets('ignores steady accelerometer readings', (tester) async {
    final samples = StreamController<AccelSample>();
    addTearDown(samples.close);
    var shakes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ShakeToReportListener(
          samples: samples.stream,
          onShake: () => shakes++,
          child: const Scaffold(body: SizedBox()),
        ),
      ),
    );

    final start = DateTime(2026, 1, 1);
    samples.add(AccelSample(0, 0, 9.81, start));
    samples.add(
      AccelSample(0.1, 0, 9.8, start.add(const Duration(milliseconds: 20))),
    );
    samples.add(
      AccelSample(0, 0.1, 9.81, start.add(const Duration(milliseconds: 60))),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(shakes, 0);
  });
}
