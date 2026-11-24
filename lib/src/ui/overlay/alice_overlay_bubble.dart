import 'dart:math' as math;

import 'package:alice/src/model/alice_http_call.dart';
import 'package:alice/src/services/storage/alice_storage.dart';
import 'package:alice/src/ui/common/theme.dart';
import 'package:flutter/material.dart';

/// Draggable floating overlay bubble displaying live Alice statistics.
/// Styled to match the Alice HTTP Inspector design language.
/// Automatically stays hidden until at least one HTTP call is recorded.
class AliceOverlayBubble extends StatefulWidget {
  final Stream<List<AliceHttpCall>> callsStream;
  final AliceStorage storage;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  /// When true, the bubble glides to the nearest screen edge on release and
  /// stays on that edge when the screen or bubble size changes.
  final bool snapToEdge;

  const AliceOverlayBubble({
    super.key,
    required this.callsStream,
    required this.storage,
    required this.onTap,
    required this.onDismiss,
    this.snapToEdge = false,
  });

  @override
  State<AliceOverlayBubble> createState() => _AliceOverlayBubbleState();
}

/// Screen edge the bubble is snapped to.
enum _BubbleEdge { left, right, top, bottom }

class _AliceOverlayBubbleState extends State<AliceOverlayBubble> {
  /// Gap between a snapped bubble and the safe-area edge.
  static const double _edgeMargin = 8;

  /// Bubble size used before the first layout.
  static const Size _defaultBubbleSize = Size(90, 34);

  final GlobalKey _bubbleKey = GlobalKey();
  Offset _offset = const Offset(16, 96);
  bool _isInitialized = false;
  bool _isDragging = false;
  _BubbleEdge? _edge;
  Size _bubbleSize = _defaultBubbleSize;

  /// Allowed top-left positions inside the safe area for the current size.
  Rect _bounds(MediaQueryData mediaQuery) {
    final screenSize = mediaQuery.size;
    final padding = mediaQuery.padding;
    final double minX = padding.left + _edgeMargin;
    final double maxX = math.max(
      minX,
      screenSize.width - padding.right - _bubbleSize.width - _edgeMargin,
    );
    final double minY = padding.top + _edgeMargin;
    final double maxY = math.max(
      minY,
      screenSize.height - padding.bottom - _bubbleSize.height - _edgeMargin,
    );
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// [offset] clamped into [bounds], then moved onto [edge].
  static Offset _onEdge(Offset offset, Rect bounds, _BubbleEdge edge) {
    final clamped = Offset(
      offset.dx.clamp(bounds.left, bounds.right),
      offset.dy.clamp(bounds.top, bounds.bottom),
    );
    return switch (edge) {
      _BubbleEdge.left => Offset(bounds.left, clamped.dy),
      _BubbleEdge.right => Offset(bounds.right, clamped.dy),
      _BubbleEdge.top => Offset(clamped.dx, bounds.top),
      _BubbleEdge.bottom => Offset(clamped.dx, bounds.bottom),
    };
  }

  /// Edge of [bounds] closest to [offset].
  static _BubbleEdge _nearestEdge(Offset offset, Rect bounds) {
    final distances = {
      _BubbleEdge.left: offset.dx - bounds.left,
      _BubbleEdge.right: bounds.right - offset.dx,
      _BubbleEdge.top: offset.dy - bounds.top,
      _BubbleEdge.bottom: bounds.bottom - offset.dy,
    };
    return distances.entries
        .reduce((a, b) => b.value < a.value ? b : a)
        .key;
  }

  void _onDragEnd() {
    if (!mounted) return;
    setState(() {
      _isDragging = false;
      if (widget.snapToEdge) {
        final bounds = _bounds(MediaQuery.of(context));
        _edge = _nearestEdge(_offset, bounds);
        _offset = _onEdge(_offset, bounds, _edge!);
      }
    });
  }

  /// Re-lays out once the real bubble size is known (it changes with the
  /// counters), so a snapped bubble stays flush with its edge.
  void _syncBubbleSize() {
    if (!widget.snapToEdge) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _bubbleKey.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return;
      if (box.size != _bubbleSize) {
        setState(() => _bubbleSize = box.size);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final padding = mediaQuery.padding;

    if (widget.snapToEdge) {
      final bounds = _bounds(mediaQuery);
      if (!_isInitialized) {
        _edge = _BubbleEdge.right;
        _offset = Offset(bounds.right, padding.top + 60);
        _isInitialized = true;
      }
      if (_isDragging || _edge == null) {
        _offset = Offset(
          _offset.dx.clamp(bounds.left, bounds.right),
          _offset.dy.clamp(bounds.top, bounds.bottom),
        );
      } else {
        _offset = _onEdge(_offset, bounds, _edge!);
      }
      _syncBubbleSize();
    } else if (!_isInitialized) {
      // Constrain position within screen safe area bounds.
      _offset = Offset(screenSize.width - 150, padding.top + 60);
      _isInitialized = true;
    } else {
      final double minX = padding.left + 8;
      final double maxX = math.max(minX, screenSize.width - padding.right - 90);
      final double minY = padding.top + 8;
      final double maxY = math.max(
        minY,
        screenSize.height - padding.bottom - 56,
      );

      _offset = Offset(
        _offset.dx.clamp(minX, maxX),
        _offset.dy.clamp(minY, maxY),
      );
    }

    return AnimatedPositioned(
      duration: widget.snapToEdge && !_isDragging
          ? const Duration(milliseconds: 220)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        key: _bubbleKey,
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanEnd: (_) => _onDragEnd(),
        onPanCancel: _onDragEnd,
        onPanUpdate: (details) {
          setState(() {
            _offset += details.delta;
          });
        },
        child: StreamBuilder<List<AliceHttpCall>>(
          stream: widget.callsStream,
          builder: (context, snapshot) {
            final stats = widget.storage.getStats();
            // The counters change the bubble's width.
            _syncBubbleSize();

            // Only show the bubble when at least one call has been recorded.
            if (stats.total == 0) {
              return const SizedBox.shrink();
            }

            final hasSuccesses = stats.successes > 0;
            final hasRedirects = stats.redirects > 0;
            final hasErrors = stats.errors > 0;
            final isLoading = stats.loading > 0;

            return Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Alice brand emblem
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AliceAppTheme.lightRed,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.search,
                            size: 12,
                            color: AliceAppTheme.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${stats.total}',
                          style: const TextStyle(
                            color: AliceAppTheme.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isLoading) ...[
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AliceAppTheme.orange,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${stats.loading}',
                                style: const TextStyle(
                                  color: AliceAppTheme.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (hasSuccesses) ...[
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check,
                                size: 13,
                                color: AliceAppTheme.green,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${stats.successes}',
                                style: const TextStyle(
                                  color: AliceAppTheme.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (hasRedirects) ...[
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.alt_route,
                                size: 13,
                                color: AliceAppTheme.orange,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${stats.redirects}',
                                style: const TextStyle(
                                  color: AliceAppTheme.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (hasErrors) ...[
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 13,
                                color: AliceAppTheme.red,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${stats.errors}',
                                style: const TextStyle(
                                  color: AliceAppTheme.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
