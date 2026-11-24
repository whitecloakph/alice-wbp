import 'package:alice/alice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A finished call (a loading one shows a spinner that never settles).
AliceHttpCall _call(int id) => AliceHttpCall(id)
  ..loading = false
  ..method = 'GET'
  ..endpoint = '/test'
  ..request = AliceHttpRequest()
  ..response = (AliceHttpResponse()..status = 200);

void main() {
  group('AliceCore shake and bubble toggle (fork)', () {
    late GlobalKey<NavigatorState> navigatorKey;
    late AliceCore core;

    Future<void> pumpApp(WidgetTester tester, AliceShakeAction action) async {
      navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigatorKey, home: const Scaffold()),
      );
      core = AliceCore(
        configuration: AliceConfiguration(
          navigatorKey: navigatorKey,
          showOverlayBubble: true,
          // Shake detection needs a real accelerometer; tests call
          // handleShake directly.
          showInspectorOnShake: false,
          shakeAction: action,
        ),
      );
      addTearDown(core.dispose);
    }

    testWidgets('defaults keep upstream behaviour', (tester) async {
      final configuration = AliceConfiguration();
      expect(configuration.shakeAction, AliceShakeAction.openInspector);
      expect(configuration.shakeThresholdGravity, 4);
      expect(configuration.snapOverlayBubbleToEdge, isFalse);
    });

    testWidgets('shake toggles the bubble, and a hidden bubble stays hidden '
        'when new calls arrive', (tester) async {
      await pumpApp(tester, AliceShakeAction.toggleOverlayBubble);

      core.addCall(_call(1));
      await tester.pump();
      expect(core.isOverlayBubbleVisible, isTrue);

      core.handleShake();
      await tester.pump();
      expect(core.isOverlayBubbleVisible, isFalse);

      core.addCall(_call(2));
      await tester.pump();
      await tester.pump();
      expect(core.isOverlayBubbleVisible, isFalse);

      core.handleShake();
      await tester.pump();
      expect(core.isOverlayBubbleVisible, isTrue);

      core.addCall(_call(3));
      await tester.pump();
      expect(core.isOverlayBubbleVisible, isTrue);
    });

    testWidgets('hideOverlayBubble survives new calls until showOverlayBubble',
        (tester) async {
      await pumpApp(tester, AliceShakeAction.openInspector);

      core.addCall(_call(1));
      await tester.pump();
      core.hideOverlayBubble();
      core.addCall(_call(2));
      await tester.pump();
      await tester.pump();
      expect(core.isOverlayBubbleVisible, isFalse);

      core.showOverlayBubble();
      await tester.pump();
      expect(core.isOverlayBubbleVisible, isTrue);
    });

    testWidgets('bubble comes back where it was left after hide and show',
        (tester) async {
      navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigatorKey, home: const Scaffold()),
      );
      core = AliceCore(
        configuration: AliceConfiguration(
          navigatorKey: navigatorKey,
          showOverlayBubble: true,
          snapOverlayBubbleToEdge: true,
          showInspectorOnShake: false,
          shakeAction: AliceShakeAction.toggleOverlayBubble,
        ),
      );
      addTearDown(core.dispose);

      core.addCall(_call(1));
      await tester.pumpAndSettle();
      final bubble = find.byIcon(Icons.search);
      expect(bubble, findsOneWidget);

      // Drag to the left side, lower down; it snaps to the left edge.
      final start = tester.getCenter(bubble);
      await tester.dragFrom(start, Offset(40 - start.dx, 400 - start.dy));
      await tester.pumpAndSettle();
      final left = tester.getTopLeft(bubble);
      expect(left.dx, lessThan(40));

      core.handleShake();
      await tester.pumpAndSettle();
      expect(bubble, findsNothing);

      core.handleShake();
      await tester.pumpAndSettle();
      expect(bubble, findsOneWidget);
      expect(tester.getTopLeft(bubble).dx, closeTo(left.dx, 0.5));
      expect(tester.getTopLeft(bubble).dy, closeTo(left.dy, 0.5));
    });

    testWidgets('calls recorded in the same frame insert one bubble',
        (tester) async {
      await pumpApp(tester, AliceShakeAction.toggleOverlayBubble);

      core.addCall(_call(1));
      core.addCall(_call(2));
      core.addCall(_call(3));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.search), findsOneWidget);

      core.handleShake();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.search), findsNothing);
    });

    testWidgets('openInspector shake action leaves the bubble alone',
        (tester) async {
      await pumpApp(tester, AliceShakeAction.openInspector);

      core.addCall(_call(1));
      await tester.pump();
      core.handleShake();
      await tester.pump();
      expect(core.isOverlayBubbleVisible, isTrue);
      expect(core.isInspectorOpened, isTrue);
    });
  });
}
