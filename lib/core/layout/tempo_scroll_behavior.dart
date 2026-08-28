import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

/// Desktop scrolling for Tempo: trackpad, mouse wheel and drag all work, the
/// Material overscroll glow is removed, and lists stop cleanly at their ends.
class TempoScrollBehavior extends MaterialScrollBehavior {
  const TempoScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
    PointerDeviceKind.mouse,
    PointerDeviceKind.touch,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  // No rubber band: with wheel input the overscroll and snap-back read as the
  // page being pulled, so the list simply stops where its content does.
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics(parent: RangeMaintainingScrollPhysics());
}
