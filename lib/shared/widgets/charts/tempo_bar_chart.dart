import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';

@immutable
class BarDatum {
  const BarDatum({
    required this.label,
    required this.amount,
    required this.tooltip,
    this.ghost,
    this.highlighted = false,
  });

  final String label;

  /// The magnitude of this bar, in whatever unit the chart is plotting. Only
  /// the ratios between bars are drawn, so seconds and counts both work.
  final double amount;

  /// The same measure in the period before, drawn as a faint marker behind the
  /// bar. Null when there is nothing to compare with.
  final double? ghost;

  final String tooltip;

  /// Today, or whichever bar the page wants to single out.
  final bool highlighted;
}

/// The bar chart used wherever days are compared.
///
/// Every bar sits in its own track, so an empty day still reads as a day. The
/// bars grow from the baseline in one movement, each a beat after the last,
/// and when the period changes they travel to their new heights instead of
/// jumping. Under the pointer a crosshair marks the bar and a readout glides
/// along the top with the figure behind it.
class TempoBarChart extends StatefulWidget {
  const TempoBarChart({
    super.key,
    required this.data,
    this.height = 150,
    this.barWidth = 26,
    this.onSelected,
  });

  final List<BarDatum> data;
  final double height;
  final double barWidth;
  final ValueChanged<int>? onSelected;

  @override
  State<TempoBarChart> createState() => _TempoBarChartState();
}

class _TempoBarChartState extends State<TempoBarChart> {
  int? _hovered;

  /// The bar the readout is parked on. Kept after the pointer leaves so the
  /// readout fades out where it stood instead of jumping home.
  int _anchor = 0;

  /// Room under the bars for the day labels; the crosshair stops there.
  static const double _labelBand = 28;
  static const double _readoutWidth = 190;

  void _hover(int? index) {
    if (_hovered == index) {
      return;
    }
    setState(() {
      _hovered = index;
      if (index != null) {
        _anchor = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<BarDatum> data = widget.data;
    if (data.isEmpty) {
      return SizedBox(height: widget.height);
    }
    double peak = 0;
    for (final BarDatum datum in data) {
      if (datum.amount > peak) {
        peak = datum.amount;
      }
      final double? ghost = datum.ghost;
      if (ghost != null && ghost > peak) {
        peak = ghost;
      }
    }
    if (peak <= 0) {
      peak = 1;
    }

    final TempoColors c = context.colors;
    final Duration glide = TempoMotion.of(context, TempoDuration.base);
    final int anchor = _anchor.clamp(0, data.length - 1);
    final bool showing = _hovered != null;

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: TempoMotion.of(context, const Duration(milliseconds: 1100)),
        curve: Curves.linear,
        builder: (BuildContext context, double t, Widget? child) => SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double slot = constraints.maxWidth / data.length;
              final double centre = slot * (anchor + 0.5);
              final double readoutLeft = (centre - _readoutWidth / 2).clamp(
                0.0,
                math.max(0.0, constraints.maxWidth - _readoutWidth),
              );

              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  AnimatedPositioned(
                    duration: glide,
                    curve: TempoCurve.gentle,
                    left: centre - 0.5,
                    top: 0,
                    bottom: _labelBand,
                    width: 1,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: showing ? 1 : 0,
                        duration: glide,
                        curve: TempoCurve.gentle,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                c.accent.withValues(alpha: 0),
                                c.accent.withValues(alpha: 0.34),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        for (int i = 0; i < data.length; i++)
                          Expanded(
                            child: MouseRegion(
                              cursor: widget.onSelected == null
                                  ? MouseCursor.defer
                                  : SystemMouseCursors.click,
                              onEnter: (_) => _hover(i),
                              onExit: (_) {
                                if (_hovered == i) {
                                  _hover(null);
                                }
                              },
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: widget.onSelected == null
                                    ? null
                                    : () => widget.onSelected!(i),
                                child: Semantics(
                                  label: data[i].tooltip,
                                  child: _Bar(
                                    datum: data[i],
                                    hovered: _hovered == i,
                                    fraction: data[i].amount / peak,
                                    ghostFraction: data[i].ghost == null
                                        ? null
                                        : data[i].ghost! / peak,
                                    progress: Interval(
                                      (i * 0.055).clamp(0.0, 0.5),
                                      1,
                                      curve: TempoCurve.entrance,
                                    ).transform(t),
                                    width: widget.barWidth,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  AnimatedPositioned(
                    duration: glide,
                    curve: TempoCurve.gentle,
                    left: readoutLeft,
                    top: 0,
                    width: _readoutWidth,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: showing ? 1 : 0,
                        duration: glide,
                        curve: TempoCurve.gentle,
                        child: Center(
                          child: _Readout(text: data[anchor].tooltip),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The floating figure that follows the pointer along the top of the chart.
class _Readout extends StatelessWidget {
  const _Readout({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TempoSpace.sm,
        vertical: TempoSpace.xxs + 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TempoRadius.sm),
        color: c.surfaceElevated.withValues(alpha: 0.96),
        border: Border.all(color: c.border),
        boxShadow: context.tempo.cardShadow,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: context.typo.labelMedium?.copyWith(color: c.textPrimary),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.datum,
    required this.hovered,
    required this.fraction,
    required this.progress,
    required this.width,
    this.ghostFraction,
  });

  final BarDatum datum;
  final bool hovered;
  final double fraction;
  final double? ghostFraction;
  final double progress;
  final double width;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final TempoTheme theme = context.tempo;
    final Duration travel = TempoMotion.of(context, TempoDuration.slow);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Center(
            child: SizedBox(
              width: width,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(width / 2.6),
                      color: c.glassFill.withValues(
                        alpha: hovered ? 0.10 : 0.055,
                      ),
                    ),
                  ),
                  if (ghostFraction != null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _Grown(
                        fraction: ghostFraction!,
                        progress: progress,
                        duration: travel,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(width / 2.6),
                            color: c.textSecondary.withValues(
                              alpha: hovered ? 0.26 : 0.16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _Grown(
                      fraction: fraction,
                      progress: progress,
                      duration: travel,
                      child: AnimatedContainer(
                        duration: TempoMotion.of(context, TempoDuration.base),
                        curve: TempoCurve.gentle,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(width / 2.6),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: datum.highlighted
                                ? <Color>[c.accent, c.accentSoft]
                                : <Color>[
                                    c.accent.withValues(
                                      alpha: hovered ? 0.78 : 0.52,
                                    ),
                                    c.accentAlt.withValues(
                                      alpha: hovered ? 0.86 : 0.62,
                                    ),
                                  ],
                          ),
                          boxShadow: datum.highlighted || hovered
                              ? theme.accentGlow(hovered ? 0.55 : 0.7)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: TempoSpace.xs + 2),
        AnimatedDefaultTextStyle(
          duration: TempoMotion.of(context, TempoDuration.base),
          curve: TempoCurve.gentle,
          style:
              context.typo.labelMedium?.copyWith(
                color: datum.highlighted || hovered
                    ? c.textPrimary
                    : c.textTertiary,
                fontWeight: datum.highlighted
                    ? FontWeight.w600
                    : FontWeight.w500,
              ) ??
              const TextStyle(),
          child: Text(datum.label, maxLines: 1),
        ),
      ],
    );
  }
}

/// Holds a bar at its share of the track. The share is tweened, so a new
/// period moves the bars from where they stood rather than redrawing them.
class _Grown extends StatelessWidget {
  const _Grown({
    required this.fraction,
    required this.progress,
    required this.duration,
    required this.child,
  });

  final double fraction;
  final double progress;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Same begin and end on the first build: the bar takes its height from
      // the entrance sweep, and only later changes are travelled.
      tween: Tween<double>(begin: fraction, end: fraction),
      duration: duration,
      curve: TempoCurve.emphasized,
      builder: (BuildContext context, double value, Widget? child) =>
          FractionallySizedBox(
            heightFactor: (value * progress).clamp(0.0, 1.0),
            child: child,
          ),
      child: child,
    );
  }
}
