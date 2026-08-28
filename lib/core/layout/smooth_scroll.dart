import 'package:flutter/material.dart';

/// Wheel scrolling that moves, rather than jumps.
///
/// Flutter's default answer to a mouse wheel on desktop is to set the scroll
/// offset at once: each notch lands the page a fixed distance further on with
/// nothing in between, which reads as stepping from section to section. This
/// controller answers a notch the way macOS and a browser do — it glides to
/// the new offset, and a run of notches keeps adding to the target so a quick
/// spin builds momentum instead of stuttering.
///
/// Dragging, trackpad panning and the scrollbar are untouched: only discrete
/// wheel input is smoothed.
class SmoothScrollController extends ScrollController {
  SmoothScrollController({super.initialScrollOffset, super.keepScrollOffset});

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _SmoothScrollPosition(
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );
}

class _SmoothScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  /// Long enough to read as motion, short enough that the page never feels
  /// behind the wheel.
  static const Duration _glide = Duration(milliseconds: 240);

  /// Where the current glide is heading. Null when nothing is in flight.
  double? _target;

  @override
  void pointerScroll(double delta) {
    if (delta == 0) {
      return;
    }
    // While a glide is still running, the next notch adds to where it was
    // going rather than to where the page happens to be right now — that is
    // what turns a fast spin into momentum instead of a series of stops.
    final bool gliding = _target != null && activity is DrivenScrollActivity;
    final double from = gliding ? _target! : pixels;
    final double target = (from + delta).clamp(
      minScrollExtent,
      maxScrollExtent,
    );
    if (target == pixels) {
      _target = null;
      return;
    }
    _target = target;
    animateTo(target, duration: _glide, curve: Curves.easeOutCubic).then((_) {
      if (_target == target) {
        _target = null;
      }
    });
  }

  @override
  void beginActivity(ScrollActivity? newActivity) {
    // Anything that is not our own glide — a drag, a fling, a jump — takes
    // over cleanly, and the next notch starts from wherever that left off.
    if (newActivity is! DrivenScrollActivity) {
      _target = null;
    }
    super.beginActivity(newActivity);
  }
}
