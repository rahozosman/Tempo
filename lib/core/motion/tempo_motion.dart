import 'package:flutter/material.dart';

/// Motion durations. Tempo animates slowly and deliberately.
class TempoDuration {
  const TempoDuration._();

  static const Duration instant = Duration(milliseconds: 110);
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration page = Duration(milliseconds: 380);
  static const Duration stagger = Duration(milliseconds: 55);
  static const Duration pulse = Duration(milliseconds: 2600);
  static const Duration ambient = Duration(seconds: 72);
}

/// Curves. Nothing in Tempo overshoots or bounces.
class TempoCurve {
  const TempoCurve._();

  /// Fast out, long settle. Entrances and reveals.
  static const Cubic entrance = Cubic(0.16, 1.0, 0.30, 1.0);

  /// Emphasised move. Selection indicators and layout morphs.
  static const Cubic emphasized = Cubic(0.20, 0.0, 0.0, 1.0);

  /// Calm symmetric ease. Hover and colour changes.
  static const Cubic gentle = Cubic(0.33, 1.0, 0.68, 1.0);

  /// Exits, slightly faster than entrances.
  static const Cubic exit = Cubic(0.40, 0.0, 1.0, 1.0);
}

/// Honours the operating system "reduce motion" setting. Every animated widget
/// in Tempo routes its duration through here.
class TempoMotion {
  const TempoMotion._();

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
