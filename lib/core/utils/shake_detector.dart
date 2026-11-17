import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// One accelerometer reading in m/s^2 per axis, with the moment it was taken.
class AccelSample {
  const AccelSample(this.x, this.y, this.z, this.t);

  final double x;
  final double y;
  final double z;
  final DateTime t;

  double get magnitude => math.sqrt(x * x + y * y + z * z);
}

/// Detects shakes in a stream of [AccelSample]s.
///
/// A shake is a sudden change in the acceleration magnitude: two jumps of at
/// least [deltaThreshold] within [burstWindow]. Shakes are reported at most
/// once per [cooldown], so a rattling device doesn't spam the listener.
class ShakeDetector {
  ShakeDetector({
    this.deltaThreshold = 15,
    this.burstWindow = const Duration(milliseconds: 250),
    this.cooldown = const Duration(seconds: 3),
  });

  /// Minimum magnitude change between consecutive samples that counts as a
  /// jerk, in m/s^2.
  final double deltaThreshold;

  /// Window in which two jerks make a shake.
  final Duration burstWindow;

  /// Minimum time between two reported shakes.
  final Duration cooldown;

  DateTime? _lastShake;
  double? _lastMagnitude;
  final List<DateTime> _jerks = [];

  /// Feeds one sample; returns true when this sample completes a shake.
  bool feed(AccelSample sample) {
    final magnitude = sample.magnitude;
    final previous = _lastMagnitude;
    _lastMagnitude = magnitude;

    final now = sample.t;
    final lastShake = _lastShake;
    if (lastShake != null && now.difference(lastShake) < cooldown) {
      return false;
    }
    if (previous == null || (magnitude - previous).abs() < deltaThreshold) {
      return false;
    }

    _jerks.removeWhere((t) => now.difference(t) > burstWindow);
    _jerks.add(now);
    if (_jerks.length < 2) return false;

    _jerks.clear();
    _lastShake = now;
    return true;
  }

  /// Emits the triggering sample for every shake detected in [samples].
  Stream<AccelSample> shakes(Stream<AccelSample> samples) async* {
    await for (final sample in samples) {
      if (feed(sample)) yield sample;
    }
  }
}

/// The device's accelerometer samples, or an empty stream on platforms
/// without an accelerometer (desktop and web).
Stream<AccelSample> deviceAccelerometerSamples() async* {
  Stream<AccelerometerEvent> events;
  try {
    events = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    );
  } on UnsupportedError {
    return;
  } catch (_) {
    return;
  }
  await for (final event in events) {
    yield AccelSample(event.x, event.y, event.z, DateTime.now());
  }
}
