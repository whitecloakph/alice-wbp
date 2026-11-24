import 'package:alice/alice.dart';
import 'package:alice/src/ui/overlay/alice_overlay_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The test surface is 800x600 with no safe-area padding; snapped bubbles sit
/// 8 px inside each edge. A drag loses up to the pan touch slop (18 px) on
/// the axis that is not snapped, hence [_slop].
const _slop = 25.0;

void main() {
  Finder bubble() => find
      .descendant(
        of: find.byType(AliceOverlayBubble),
        matching: find.byType(Material),
      )
      .first;

  Future<AliceMemoryStorage> pumpBubble(
    WidgetTester tester, {
    required bool snapToEdge,
  }) async {
    final storage = AliceMemoryStorage(maxCallsCount: 10);
    final call = AliceHttpCall(1)
      ..method = 'GET'
      ..endpoint = '/test'
      ..request = AliceHttpRequest()
      ..response = (AliceHttpResponse()..status = 200);
    storage.addCall(call);
    storage.addResponse(call.response!, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              AliceOverlayBubble(
                callsStream: storage.callsStream,
                storage: storage,
                onTap: () {},
                onDismiss: () {},
                snapToEdge: snapToEdge,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return storage;
  }

  group('AliceOverlayBubble edge snapping (fork)', () {
    testWidgets('starts flush with the right edge', (tester) async {
      await pumpBubble(tester, snapToEdge: true);
      expect(tester.getTopRight(bubble()).dx, closeTo(800 - 8, 0.5));
    });

    testWidgets('snaps to the left edge when released near it',
        (tester) async {
      await pumpBubble(tester, snapToEdge: true);
      final start = tester.getCenter(bubble());
      await tester.dragFrom(start, Offset(60 - start.dx, 250 - start.dy));
      await tester.pumpAndSettle();
      final topLeft = tester.getTopLeft(bubble());
      expect(topLeft.dx, closeTo(8, 0.5));
      // Keeps the height it was dropped at.
      expect(tester.getCenter(bubble()).dy, closeTo(250, _slop));
    });

    testWidgets('snaps to the bottom edge when released near it',
        (tester) async {
      await pumpBubble(tester, snapToEdge: true);
      final start = tester.getCenter(bubble());
      await tester.dragFrom(start, Offset(400 - start.dx, 585 - start.dy));
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(bubble()).dy, closeTo(600 - 8, 0.5));
      expect(tester.getCenter(bubble()).dx, closeTo(400, _slop));
    });

    testWidgets('stays where dropped when snapping is off', (tester) async {
      await pumpBubble(tester, snapToEdge: false);
      final start = tester.getCenter(bubble());
      await tester.dragFrom(start, Offset(300 - start.dx, 300 - start.dy));
      await tester.pumpAndSettle();
      final center = tester.getCenter(bubble());
      expect(center.dx, closeTo(300, _slop));
      expect(center.dy, closeTo(300, _slop));
      // Not moved onto any edge.
      expect(tester.getTopLeft(bubble()).dx, greaterThan(100));
      expect(tester.getTopRight(bubble()).dx, lessThan(700));
    });

    testWidgets('stays flush right when the bubble grows', (tester) async {
      final storage = await pumpBubble(tester, snapToEdge: true);
      final error = AliceHttpCall(2)
        ..method = 'GET'
        ..endpoint = '/fail'
        ..request = AliceHttpRequest()
        ..response = (AliceHttpResponse()..status = 500);
      storage.addCall(error);
      storage.addResponse(error.response!, 2);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(tester.getTopRight(bubble()).dx, closeTo(800 - 8, 0.5));
    });
  });
}
