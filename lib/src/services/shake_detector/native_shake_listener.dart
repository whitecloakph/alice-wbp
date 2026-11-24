import 'dart:async';

import 'package:flutter/services.dart';

/// Listens to the iOS shake gesture forwarded by the fork's iOS plugin part
/// (`AlicePlugin`). [start] asks the plugin whether it is there first; when it
/// is not (plugin not linked, web, other platforms) it calls [onUnavailable]
/// instead, so the caller can fall back to the accelerometer.
class AliceNativeShakeListener {
  AliceNativeShakeListener({required this.onShake, this.onUnavailable});

  static const MethodChannel controlChannel =
      MethodChannel('alice/shake_control');
  static const EventChannel shakeChannel = EventChannel('alice/shake');

  /// Called once per shake gesture.
  final void Function() onShake;

  /// Called when the native shake gesture is not available.
  final void Function()? onUnavailable;

  StreamSubscription<dynamic>? _subscription;
  bool _disposed = false;

  /// Starts listening, or calls [onUnavailable].
  Future<void> start() async {
    bool available;
    try {
      available = await controlChannel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      // Missing plugin (web, plugin not linked), a platform error, or an
      // unexpected answer: never let it escape (start() is not awaited).
      available = false;
    }
    if (_disposed) return;
    if (!available) {
      onUnavailable?.call();
      return;
    }
    _subscription = shakeChannel.receiveBroadcastStream().listen(
      (_) => onShake(),
      onError: (Object _) {},
    );
  }

  /// Stops listening.
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
  }
}
