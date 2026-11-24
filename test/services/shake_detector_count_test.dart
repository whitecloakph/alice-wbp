import 'package:alice/src/services/shake_detector/shake_detector_io.dart';
import 'package:flutter_test/flutter_test.dart';

/// A reading of [g] gravities on one axis.
const double _ms2 = 9.80665;

void main() {
  group('ShakeDetector shake count and cooldown (fork)', () {
    late int fired;
    late int t0;

    ShakeDetector detector({int minimum = 1, int cooldown = 0}) {
      fired = 0;
      // The detector ignores shakes within the slop of its creation time.
      t0 = DateTime.now().millisecondsSinceEpoch + 1000;
      return ShakeDetector.waitForStart(
        onPhoneShake: () => fired++,
        shakeThresholdGravity: 2.7,
        minimumShakeCount: minimum,
        cooldownMS: cooldown,
      );
    }

    void shake(ShakeDetector d, int atMs, {double g = 3.5}) =>
        d.handleAcceleration(g * _ms2, 0, 0, nowMs: t0 + atMs);

    test('defaults fire on every shake, as upstream', () {
      final d = detector();
      shake(d, 0);
      shake(d, 600);
      expect(fired, 2);
    });

    test('readings below the threshold never count', () {
      final d = detector(minimum: 1);
      shake(d, 0, g: 2.0);
      shake(d, 600, g: 2.6);
      expect(fired, 0);
    });

    test('a single jolt does not fire when two shakes are required', () {
      final d = detector(minimum: 2);
      shake(d, 0);
      expect(fired, 0);
      // Readings within the 500 ms slop belong to the same jolt.
      shake(d, 100);
      shake(d, 300);
      expect(fired, 0);
    });

    test('two shakes close together fire once', () {
      final d = detector(minimum: 2);
      shake(d, 0);
      shake(d, 700);
      expect(fired, 1);
    });

    test('two shakes too far apart do not fire', () {
      final d = detector(minimum: 2);
      shake(d, 0);
      shake(d, 4000); // count resets after 3 s
      expect(fired, 0);
      shake(d, 4700);
      expect(fired, 1);
    });

    test('cooldown keeps one long shake from firing twice', () {
      final d = detector(minimum: 2, cooldown: 2000);
      shake(d, 0);
      shake(d, 600); // fires
      shake(d, 1200);
      shake(d, 1800); // inside cooldown
      expect(fired, 1);
      shake(d, 2700);
      shake(d, 3300); // after cooldown: fires again
      expect(fired, 2);
    });
  });
}
