import 'package:flutter/material.dart';

import '../../../core/motion/tempo_animations.dart';
import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/utilities/tempo_format.dart';

/// The shape of a single day: twenty-four columns, one per hour, each as tall
/// as the minutes actually spent at the computer in that hour.
class DayTimeline extends StatelessWidget {
  const DayTimeline({
    super.key,
    required this.minutesByHour,
    this.height = 128,
    this.markers = const <int>[0, 6, 12, 18],
  });

  /// 24 values, active minutes per hour.
  final List<double> minutesByHour;

  final double height;

  /// Hours that get a label under the chart.
  final List<int> markers;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final int hours = minutesByHour.length;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: TempoMotion.of(
            context,
            const Duration(milliseconds: 1200),
          ),
          curve: Curves.linear,
          builder: (BuildContext context, double t, Widget? child) => SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (int hour = 0; hour < hours; hour++)
                  Expanded(
                    child: _HourColumn(
                      hour: hour,
                      minutes: minutesByHour[hour],
                      progress: Interval(
                        (hour * 0.02).clamp(0.0, 0.55),
                        1,
                        curve: TempoCurve.entrance,
                      ).transform(t),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: TempoSpace.xs),
        Container(height: 1, color: c.border),
        const SizedBox(height: TempoSpace.xs),
        Row(
          children: <Widget>[
            for (int hour = 0; hour < hours; hour++)
              Expanded(
                child: markers.contains(hour)
                    ? Text(
                        TempoFormat.hourLabel(hour),
                        style: context.typo.bodySmall?.copyWith(
                          fontSize: 11,
                          color: c.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
        ],
      ),
    );
  }
}

class _HourColumn extends StatelessWidget {
  const _HourColumn({
    required this.hour,
    required this.minutes,
    required this.progress,
  });

  final int hour;
  final double minutes;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final double intensity = (minutes / 60).clamp(0.0, 1.0);
    final Color tone = Color.lerp(c.accent, c.accentSoft, intensity)!;
    final int rounded = minutes.round();

    return Tooltip(
      message:
          '${TempoFormat.hourLabel(hour)}  ·  ${rounded == 0 ? 'nothing recorded' : '${rounded}m active'}',
      child: HoverBuilder(
        builder: (BuildContext context, bool hovered) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(TempoRadius.xs - 2),
                  color: c.glassFill.withValues(
                    alpha: hovered ? 0.10 : 0.05,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: (intensity * progress).clamp(0.0, 1.0),
                  child: AnimatedContainer(
                    duration: TempoMotion.of(context, TempoDuration.base),
                    curve: TempoCurve.gentle,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(TempoRadius.xs - 2),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: <Color>[
                          tone.withValues(alpha: hovered ? 0.95 : 0.72),
                          Color.lerp(tone, c.accentSoft, 0.5)!.withValues(
                            alpha: hovered ? 1 : 0.88,
                          ),
                        ],
                      ),
                      boxShadow: hovered
                          ? context.tempo.glowOf(tone, 0.6)
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
