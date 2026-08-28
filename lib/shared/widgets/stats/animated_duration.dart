import 'package:flutter/material.dart';

import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/theme/tempo_typography.dart';
import '../../../core/utilities/tempo_format.dart';

/// A duration that counts up to its value when it appears.
///
/// The figures are tabular, so the number never jitters while it counts, and
/// the unit letters are set smaller and quieter than the digits.
class AnimatedDuration extends StatelessWidget {
  const AnimatedDuration({
    super.key,
    required this.value,
    this.style,
    this.unitStyle,
    this.duration = const Duration(milliseconds: 1150),
    this.unitScale = 0.46,
  });

  final Duration value;
  final TextStyle? style;
  final TextStyle? unitStyle;
  final Duration duration;

  /// Unit size relative to the digits.
  final double unitScale;

  @override
  Widget build(BuildContext context) {
    final TextStyle digits =
        (style ?? context.typo.displaySmall ?? const TextStyle()).copyWith(
          fontFeatures: TempoTypography.numeric,
        );
    final TextStyle unit =
        unitStyle ??
        digits.copyWith(
          fontSize: (digits.fontSize ?? 32) * unitScale,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          color: context.colors.textSecondary,
        );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.inSeconds.toDouble()),
      duration: TempoMotion.of(context, duration),
      curve: TempoCurve.entrance,
      builder: (BuildContext context, double seconds, Widget? child) {
        final int minutes = (seconds / 60).floor();
        final int hours = minutes ~/ 60;
        final int rest = minutes % 60;
        return Text.rich(
          TextSpan(
            children: <InlineSpan>[
              if (hours > 0) ...<InlineSpan>[
                TextSpan(text: '$hours', style: digits),
                TextSpan(text: 'h', style: unit),
                TextSpan(text: ' ', style: unit),
              ],
              TextSpan(text: '$rest', style: digits),
              TextSpan(text: 'm', style: unit),
            ],
          ),
          maxLines: 1,
          semanticsLabel: TempoFormat.hmSpoken(value),
        );
      },
    );
  }
}

/// A plain number that counts up. Used for session counts and percentages.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 950),
  });

  final int value;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final TextStyle resolved =
        (style ?? context.typo.displaySmall ?? const TextStyle()).copyWith(
          fontFeatures: TempoTypography.numeric,
        );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: TempoMotion.of(context, duration),
      curve: TempoCurve.entrance,
      builder: (BuildContext context, double current, Widget? child) => Text(
        '${current.round()}$suffix',
        style: resolved,
        maxLines: 1,
        semanticsLabel: '$value$suffix',
      ),
    );
  }
}
