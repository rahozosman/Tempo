import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';

/// The single glass primitive every Tempo surface is built from.
///
/// One place defines the fill, the hairline border, the top sheen and the
/// optional backdrop blur, so no screen can invent its own card style.
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
  final Color? borderColor;
  final double borderWidth;

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
    final TempoColors c = context.colors;
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final Color resolvedFill = fill ?? c.glassFill;

    Widget content = Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: gradient ?? TempoGradients.glass(resolvedFill),
        border: Border.all(
          color: borderColor ?? c.border,
          width: borderWidth,
        ),
      ),
      child: child,
    );

    if (sheen || overlay != null) {
      content = Stack(
        children: <Widget>[
          content,
          if (sheen)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    gradient: TempoGradients.sheen(c),
                  ),
                ),
              ),
            ),
          if (overlay != null)
            Positioned.fill(child: IgnorePointer(child: overlay!)),
        ],
      );
    }

    Widget surface = ClipRRect(
      borderRadius: borderRadius,
      child: blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: content,
            )
          : content,
    );

    final List<BoxShadow> resolvedShadows = shadows ?? context.tempo.cardShadow;
    if (resolvedShadows.isNotEmpty) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: resolvedShadows,
        ),
        child: surface,
      );
    }
    return surface;
  }
}
