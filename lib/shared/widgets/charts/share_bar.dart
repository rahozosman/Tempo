import 'package:flutter/material.dart';

import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_palette.dart';
import '../../../core/theme/tempo_theme.dart';

/// The horizontal bar that shows one application's share of a period.
///
/// It fills once when it appears and brightens with its row, and is the same
/// component in the dashboard lists and on the Applications screen.
class ShareBar extends StatelessWidget {
  const ShareBar({
    super.key,
    required this.share,
    required this.tone,
    this.hovered = false,
    this.height = 8,
  });

  final double share;
  final Color tone;
  final bool hovered;
  final double height;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final double radius = height / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: c.glassFill.withValues(alpha: 0.09)),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: share.clamp(0.0, 1.0)),
              duration: TempoMotion.of(
                context,
                const Duration(milliseconds: 900),
              ),
              curve: TempoCurve.entrance,
              builder: (BuildContext context, double value, Widget? child) =>
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: child,
                  ),
              child: AnimatedContainer(
                duration: TempoMotion.of(context, TempoDuration.base),
                curve: TempoCurve.gentle,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: TempoPalette.gradientFor(tone),
                  boxShadow: hovered ? context.tempo.glowOf(tone, 0.5) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
