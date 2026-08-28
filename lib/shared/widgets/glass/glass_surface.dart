import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';
import '../ambient_background.dart';

/// The single glass primitive every Tempo surface is built from.
///
/// One place defines the fill, the edge, the top sheen and the optional
/// backdrop blur, so no screen can invent its own card style.
///
/// Two things give it its character:
///
///  * **Continuous corners.** The shape is a superellipse rather than a
///    rectangle with circular arcs, so the curve eases into the straight edge
///    with no visible seam — the rounding iOS and macOS use for their own
///    windows and icons.
///  * **A living edge.** There is no hairline grid line around a card. Its edge
///    is a slow sweep of the three product colours — blue, purple, violet —
///    turning in the same phase as the lights in the room behind it, so every
///    surface belongs to the same weather. At rest it is faint; under the
///    pointer it comes forward.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    this.child,
    this.padding,
    this.width,
    this.height,
    this.radius = TempoRadius.lg,
    this.blur = 0,
    this.fill,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1,
    this.edge = 0.5,
    this.shadows,
    this.sheen = true,
    this.overlay,
    this.alignment,
  });

  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final double radius;

  /// Backdrop blur sigma. Zero keeps the surface cheap: use blur only for the
  /// large chrome panels, not for long lists.
  final double blur;

  final Color? fill;
  final Gradient? gradient;

  /// A tint laid under the coloured edge. Left null, the edge alone draws the
  /// outline.
  final Color? borderColor;

  final double borderWidth;

  /// How strongly the coloured edge shows, 0 to 1. Half at rest; a hovered
  /// card asks for nearly all of it.
  final double edge;

  /// Pass an empty list to suppress the default shadow (for example when a
  /// parent already animates one).
  final List<BoxShadow>? shadows;

  final bool sheen;

  /// Painted over the content but inside the clip, so a hover sheen or any
  /// other wash follows the surface's own rounded shape.
  final Widget? overlay;

  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final TempoTheme theme = context.tempo;
    final TempoColors c = theme.colors;
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final RoundedSuperellipseBorder shape = RoundedSuperellipseBorder(
      borderRadius: borderRadius,
    );
    final Color resolvedFill = fill ?? c.glassFill;

    Widget content = Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      decoration: ShapeDecoration(
        shape: shape,
        gradient: gradient ?? TempoGradients.glass(resolvedFill),
      ),
      child: child,
    );

    content = Stack(
      children: <Widget>[
        content,
        if (sheen)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: shape,
                  gradient: TempoGradients.sheen(c),
                ),
              ),
            ),
          ),
        if (overlay != null)
          Positioned.fill(child: IgnorePointer(child: overlay!)),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _LivingEdge(
                  phase: ambientPhase,
                  colors: c,
                  radius: radius,
                  width: borderWidth,
                  strength: (edge * theme.accentIntensity).clamp(0.0, 1.0),
                  base: borderColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    Widget surface = ClipRSuperellipse(
      borderRadius: borderRadius,
      child: blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: theme.blur(blur),
                sigmaY: theme.blur(blur),
              ),
              child: content,
            )
          : content,
    );

    final List<BoxShadow> resolvedShadows = shadows ?? theme.cardShadow;
    if (resolvedShadows.isNotEmpty) {
      surface = DecoratedBox(
        decoration: ShapeDecoration(shape: shape, shadows: resolvedShadows),
        child: surface,
      );
    }
    return surface;
  }
}

/// The edge: a sweep of the three product colours around a continuous-corner
/// outline, turning with the room.
///
/// It repaints from the shared phase directly — no widget rebuilds — and only
/// the stroke is drawn, so a screen of twenty cards costs twenty thin arcs a
/// frame.
class _LivingEdge extends CustomPainter {
  _LivingEdge({
    required this.phase,
    required this.colors,
    required this.radius,
    required this.width,
    required this.strength,
    this.base,
  }) : super(repaint: phase);

  final ValueListenable<double> phase;
  final TempoColors colors;
  final double radius;
  final double width;
  final double strength;
  final Color? base;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    // The stroke is centred on the outline, so the shape is drawn half a
    // stroke inside the box and nothing is clipped away.
    final Rect inner = rect.deflate(width / 2);
    final RSuperellipse outline = RSuperellipse.fromRectAndRadius(
      inner,
      Radius.circular(math.max(0, radius - width / 2)),
    );

    final Color? tint = base;
    if (tint != null && tint.a > 0) {
      canvas.drawRSuperellipse(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = tint,
      );
    }

    if (strength <= 0) {
      return;
    }

    // A whole turn of the room is one turn of the edge. The three colours
    // hand over to one another around the corner rather than at a seam.
    final double angle = phase.value * math.pi * 2;
    final double alpha = (0.18 + 0.62 * strength).clamp(0.0, 1.0);
    canvas.drawRSuperellipse(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = SweepGradient(
          colors: <Color>[
            colors.accent.withValues(alpha: alpha),
            colors.accentAlt.withValues(alpha: alpha * 0.9),
            colors.accentSoft.withValues(alpha: alpha),
            colors.accent.withValues(alpha: alpha * 0.55),
            colors.accent.withValues(alpha: alpha),
          ],
          stops: const <double>[0.0, 0.3, 0.6, 0.82, 1.0],
          transform: GradientRotation(angle),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _LivingEdge old) =>
      old.colors.accent != colors.accent ||
      old.colors.accentAlt != colors.accentAlt ||
      old.colors.accentSoft != colors.accentSoft ||
      old.radius != radius ||
      old.width != width ||
      old.strength != strength ||
      old.base != base ||
      old.phase != phase;
}
