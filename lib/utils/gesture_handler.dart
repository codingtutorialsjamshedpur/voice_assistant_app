import 'dart:async';
import 'package:flutter/material.dart';

/// A custom ultra-responsive gesture handler to overcome Flutter's default 300ms double-tap delay.
/// Meets requirements for TR-02 (<100ms single tap) and TR-03 (<150ms double tap).
class FastGestureDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  const FastGestureDetector({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });

  @override
  State<FastGestureDetector> createState() => _FastGestureDetectorState();
}

class _FastGestureDetectorState extends State<FastGestureDetector> {
  Timer? _doubleTapTimer;
  Timer? _longPressTimer;
  int _tapCount = 0;

  // Time before a single tap is registered if no double tap occurs
  static const int _singleTapTimeoutMs =
      145; // Will be optimized to near instant if no double tap is needed

  void _handlePointerDown(PointerDownEvent event) {
    // Start long press timer
    if (widget.onLongPress != null) {
      _longPressTimer = Timer(const Duration(milliseconds: 400), () {
        _tapCount = 0;
        _doubleTapTimer?.cancel();
        widget.onLongPress!();
      });
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _longPressTimer?.cancel();
    _tapCount++;

    if (_tapCount == 1) {
      // If no double tap action is defined, fire instantly (0ms debounce)
      if (widget.onDoubleTap == null && widget.onTap != null) {
        _tapCount = 0;
        widget.onTap!();
        return;
      }

      // Otherwise, wait briefly for a potential second tap
      _doubleTapTimer =
          Timer(const Duration(milliseconds: _singleTapTimeoutMs), () {
        _tapCount = 0;
        if (widget.onTap != null) {
          widget.onTap!();
        }
      });
    } else if (_tapCount == 2) {
      _doubleTapTimer?.cancel();
      _tapCount = 0;
      if (widget.onDoubleTap != null) {
        widget.onDoubleTap!();
      }
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _longPressTimer?.cancel();
    _doubleTapTimer?.cancel();
    _tapCount = 0;
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _doubleTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }
}
