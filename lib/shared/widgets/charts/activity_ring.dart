import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_theme.dart';

/// The signature dial on Home: how much of the last twenty-four hours went to
/// the computer, split into the part spent working and the part spent idle.
///
/// The arc draws itself once, from the top, clockwise. The glow is painted as a
/// wider, fainter arc rather than a blur filter, so it costs nothing.
class ActivityRing extends StatelessWidget {
  const ActivityRing({
    super.key,
    required this.active,
    required this.idle,
    this.reference = const Duration(hours: 24),
    this.size = 236,
    this.thickness = 15,
    this.child,
  });

  final Duration active;
  final Duration idle;

  /// The whole the arcs are measured against.
  final Duration reference;

  final double size;
  final double thickness;

  /// Sits in the middle of the ring, usually the hero figure.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final TempoTheme theme = context.tempo;
    final double whole = reference.inSeconds.toDouble();
    final double activeShare = whole <= 0
        ? 0
        : (active.inSeconds / whole).clamp(0.0, 1.0);
    final double idleShare = whole <= 0
        ? 0
        : (idle.inSeconds / whole).clamp(0.0, 1.0 - activeShare);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: TempoMotion.of(context, const Duration(milliseconds: 1400)),
        curve: TempoCurve.entrance,
        builder: (BuildContext context, double t, Widget? content) =>
            CustomPaint(
              painter: _RingPainter(
                colors: theme.colors,
                intensity: theme.accentIntensity,
                activeShare: activeShare,
                idleShare: idleShare,
                progress: t,
                thickness: thickness,
              ),
              child: content,
            ),
        child: child == null
            ? null
            : Center(
                child: Padding(
                  padding: EdgeInsets.all(thickness * 2.2),
                  child: child,
                ),
              ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.colors,
    required this.intensity,
    required this.activeShare,
    required this.idleShare,
    required this.progress,
    required this.thickness,
  });

  final TempoColors colors;
  final double intensity;
  final double activeShare;
  final double idleShare;
  final double progress;
  final double thickness;

  static const double _start = -math.pi / 2;
  static const double _full = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) - thickness) / 2;
    final Rect rect = Rect.fromCircle(center: centre, radius: radius);

    // Track.
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = colors.textTertiary.withValues(alpha: 0.16),
    );

    final double activeSweep = _full * activeShare * progress;
    final double idleSweep = _full * idleShare * progress;

    // Idle continues where active stops, thinner and quieter: it is time the
    // machine was awake but untouched, not work.
    if (idleSweep > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        _start + activeSweep,
        idleSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = thickness * 0.5
          ..color = colors.textSecondary.withValues(alpha: 0.42),
      );
    }

    if (activeSweep > 0.001) {
      final Shader shader = SweepGradient(
        startAngle: 0,
        endAngle: _full,
        colors: <Color>[
          colors.accent,
          colors.accentAlt,
          colors.accentSoft,
          colors.accent,
        ],
        transform: const GradientRotation(_start),
      ).createShader(rect);

      // Glow: the same arc, wider and faint. No blur filter involved.
      canvas.drawArc(
        rect,
        _start,
        activeSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = thickness * 2.1
          ..color = colors.accentAlt.withValues(
            alpha: (0.13 * intensity).clamp(0.0, 1.0),
          ),
      );

      canvas.drawArc(
        rect,
        _start,
        activeSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = thickness
          ..shader = shader,
      );

      // The travelling head, echoing the Tempo mark.
      final double angle = _start + activeSweep;
      final Offset head =
          centre + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(
        head,
        thickness * 0.62,
        Paint()
          ..color = colors.accentSoft.withValues(
            alpha: (0.22 * intensity).clamp(0.0, 1.0),
          ),
      );
      canvas.drawCircle(
        head,
        thickness * 0.26,
        Paint()..color = colors.textPrimary,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.activeShare != activeShare ||
      oldDelegate.idleShare != idleShare ||
      oldDelegate.intensity != intensity ||
      oldDelegate.colors.accent != colors.accent;
}
