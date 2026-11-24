import 'package:alice/src/services/shake_detector/native_shake_listener.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(
        AliceNativeShakeListener.controlChannel, null);
    messenger.setMockStreamHandler(AliceNativeShakeListener.shakeChannel, null);
  });

  group('AliceNativeShakeListener (fork)', () {
    test('forwards each native shake event', () async {
      messenger.setMockMethodCallHandler(
        AliceNativeShakeListener.controlChannel,
        (call) async => call.method == 'isAvailable' ? true : null,
      );
      MockStreamHandlerEventSink? sink;
      messenger.setMockStreamHandler(
        AliceNativeShakeListener.shakeChannel,
        MockStreamHandler.inline(onListen: (_, events) => sink = events),
      );
      var shakes = 0;
      var unavailable = false;
      final listener = AliceNativeShakeListener(
        onShake: () => shakes++,
        onUnavailable: () => unavailable = true,
      );

      await listener.start();
      await Future<void>.delayed(Duration.zero);
      sink!.success(null);
      sink!.success(null);
      await Future<void>.delayed(Duration.zero);

      expect(shakes, 2);
      expect(unavailable, isFalse);
      listener.dispose();
    });

    test('reports unavailable when the iOS part is missing', () async {
      var unavailable = false;
      final listener = AliceNativeShakeListener(
        onShake: () {},
        onUnavailable: () => unavailable = true,
      );

      await listener.start();

      expect(unavailable, isTrue);
    });

    test('treats an unexpected answer as unavailable', () async {
      messenger.setMockMethodCallHandler(
        AliceNativeShakeListener.controlChannel,
        (call) async => 'yes',
      );
      var unavailable = false;
      final listener = AliceNativeShakeListener(
        onShake: () {},
        onUnavailable: () => unavailable = true,
      );

      await listener.start();

      expect(unavailable, isTrue);
    });

    test('does nothing after dispose', () async {
      messenger.setMockMethodCallHandler(
        AliceNativeShakeListener.controlChannel,
        (call) async => true,
      );
      var unavailable = false;
      final listener = AliceNativeShakeListener(
        onShake: () {},
        onUnavailable: () => unavailable = true,
      );
      final starting = listener.start();
      listener.dispose();
      await starting;
      expect(unavailable, isFalse);
    });
  });
}
