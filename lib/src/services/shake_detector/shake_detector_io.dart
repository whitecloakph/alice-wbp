import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sensors_plus/sensors_plus.dart';

/// Callback for phone shakes
typedef PhoneShakeCallback = void Function();

/// ShakeDetector class for phone shake functionality
class ShakeDetector {
  /// User callback for phone shake
  final PhoneShakeCallback? onPhoneShake;

  /// Shake detection threshold
  final double shakeThresholdGravity;

  /// Minimum time between shake
  final int shakeSlopTimeMS;

  /// Time before shake count resets
  final int shakeCountResetTime;

  /// Shakes (each at least [shakeSlopTimeMS] apart, none more than
  /// [shakeCountResetTime] after the previous) needed before [onPhoneShake]
  /// fires. 1 (the default) fires on every shake, as upstream (fork).
  final int minimumShakeCount;

  /// Time after [onPhoneShake] fires during which shakes are ignored, so
  /// one long shake fires once. 0 (the default) as upstream (fork).
  final int cooldownMS;

  int _shakeTimestamp = DateTime.now().millisecondsSinceEpoch;
  int _shakeCount = 0;
  int _cooldownUntil = 0;

  /// StreamSubscription for Accelerometer events
  StreamSubscription<AccelerometerEvent>? streamSubscription;

  /// This constructor waits until [startListening] is called
  ShakeDetector.waitForStart({
    this.onPhoneShake,
    this.shakeThresholdGravity = 2.7,
    this.shakeSlopTimeMS = 500,
    this.shakeCountResetTime = 3000,
    this.minimumShakeCount = 1,
    this.cooldownMS = 0,
  });

  /// This constructor automatically calls [startListening] and starts detection and callbacks.\
  ShakeDetector.autoStart({
    this.onPhoneShake,
    this.shakeThresholdGravity = 2.7,
    this.shakeSlopTimeMS = 500,
    this.shakeCountResetTime = 3000,
    this.minimumShakeCount = 1,
    this.cooldownMS = 0,
  }) {
    startListening();
  }

  /// Starts listening to accelerometer events
  void startListening() {
    if (Platform.isAndroid || Platform.isIOS) {
      streamSubscription = accelerometerEventStream().listen(
        _onAccelerometerEvent,
      );
    }
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    handleAcceleration(event.x, event.y, event.z);
  }

  /// Handles one accelerometer reading (m/s²). [nowMs] is for tests.
  @visibleForTesting
  void handleAcceleration(double x, double y, double z, {int? nowMs}) {
    const double g = 9.80665;
    final double gX = x / g;
    final double gY = y / g;
    final double gZ = z / g;

    // gForce will be close to 1 when there is no movement.
    final double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);
    if (gForce <= shakeThresholdGravity) {
      return;
    }

    final int now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (now < _cooldownUntil) {
      return;
    }
    // ignore shake events too close to each other (500ms)
    if (_shakeTimestamp + shakeSlopTimeMS > now) {
      return;
    }
    // reset the shake count after 3 seconds of no shakes
    if (_shakeTimestamp + shakeCountResetTime < now) {
      _shakeCount = 0;
    }
    _shakeTimestamp = now;
    _shakeCount++;
    if (_shakeCount < minimumShakeCount) {
      return;
    }
    _shakeCount = 0;
    _cooldownUntil = now + cooldownMS;
    onPhoneShake?.call();
  }

  /// Stops listening to accelerometer events
  void stopListening() {
    dispose();
  }

  /// Disposes all subscriptions.
  void dispose() {
    streamSubscription?.cancel();
    streamSubscription = null;
  }
}
