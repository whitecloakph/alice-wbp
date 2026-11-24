import 'package:alice/src/core/alice_core.dart';
import 'package:alice/src/ui/overlay/alice_overlay_bubble.dart';
import 'package:flutter/widgets.dart';

/// Service managing the lifecycle and attachment of the [AliceOverlayBubble].
class AliceOverlayService {
  OverlayEntry? _overlayEntry;

  /// Where the user last released the bubble. Kept across re-inserts, so the
  /// bubble comes back to the same spot after it is hidden and shown or the
  /// inspector closes.
  AliceBubblePlacement? _placement;

  /// True from [ensureInserted] until the end of that frame: a new entry is
  /// not `mounted` before the next frame, and treating it as missing made two
  /// calls recorded in the same frame insert two bubbles (fork fix).
  bool _awaitingMount = false;

  /// Returns true if the overlay is currently inserted into the tree.
  bool get isInserted =>
      _overlayEntry != null && (_overlayEntry!.mounted || _awaitingMount);

  /// Ensures the overlay entry is inserted into [overlayState].
  void ensureInserted({
    required OverlayState? overlayState,
    required AliceCore core,
  }) {
    if (overlayState == null) {
      return;
    }

    if (_overlayEntry != null) {
      if (_overlayEntry!.mounted || _awaitingMount) {
        return;
      }
      _overlayEntry = null;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        if (core.isInspectorOpened) {
          return const SizedBox.shrink();
        }
        return AliceOverlayBubble(
          callsStream: core.callsStream,
          storage: core.configuration.aliceStorage,
          onTap: () {
            if (!core.isInspectorOpened) {
              core.navigateToCallListScreen();
            }
          },
          onDismiss: remove,
          snapToEdge: core.configuration.snapOverlayBubbleToEdge,
          initialPlacement: _placement,
          onPlacementChanged: (placement) => _placement = placement,
        );
      },
    );

    overlayState.insert(_overlayEntry!);
    _awaitingMount = true;
    final inserted = _overlayEntry;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(_overlayEntry, inserted)) _awaitingMount = false;
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Rebuilds the overlay entry if inserted (e.g. when inspector opens/closes).
  void markNeedsBuild() {
    _overlayEntry?.markNeedsBuild();
  }

  /// Removes the overlay entry from the overlay if attached.
  void remove() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _awaitingMount = false;
  }
}
