import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_info.dart';
import '../../core/motion/tempo_motion.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/theme/tempo_typography.dart';

/// How far the launch has handed over to the app, 0 to 1.
///
/// The shell reads this to bring the sidebar and the page in underneath the
/// launch as it dissolves, so the two read as one movement rather than a
/// splash being replaced by an interface.
final ValueNotifier<double> launchReveal = ValueNotifier<double>(0);

/// True once the launch has finished and its overlay can go.
final ValueNotifier<bool> launchDone = ValueNotifier<bool>(false);

/// The opening.
///
/// The room is already drifting behind it. The Tempo mark draws itself —
/// the orbit sweeps in, the inner arc follows, the travelling point lands
/// with a bloom — and the wordmark settles beneath it. Then the mark flies to
/// its place at the top of the sidebar and shrinks to size while the
/// interface arrives around it, so the logo you watched is the one sitting in
/// the corner when the app is ready.
///
/// It runs once, for a little over two seconds. Under reduced motion it is a
/// short fade and nothing more.
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  /// Where the sidebar's own mark sits, in shell coordinates: under the
  /// title bar, the brand row is inset 12 and 42 tall, and the mark is drawn
  /// 20 wide inside a 30-wide tile.
  static const Offset markHome = Offset(12 + 15, TempoSizes.titleBar + 21);
  static const double markHomeSize = 20;
  static const double markSize = 104;

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    launchReveal.value = 0;
    if (TempoMotion.reduced(context)) {
      _controller.duration = const Duration(milliseconds: 360);
    }
    _controller
      ..addListener(_publish)
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          launchReveal.value = 1;
          launchDone.value = true;
        }
      })
      ..forward();
  }

  void _publish() {
    final double t = _controller.value;
    // The hand-over is the last fifth. Before it the app is fully hidden.
    launchReveal.value = TempoCurve.entrance.transform(_segment(t, 0.80, 1.0));
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_publish)
      ..dispose();
    super.dispose();
  }

  static double _segment(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final TempoTheme theme = context.tempo;
    final TempoColors c = theme.colors;
    final bool reduced = TempoMotion.reduced(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double t = _controller.value;
        if (reduced) {
          return IgnorePointer(
            child: Opacity(
              opacity: 1 - TempoCurve.exit.transform(t),
              child: ColoredBox(color: c.backdrop),
            ),
          );
        }

        final double handover = TempoCurve.emphasized.transform(
          _segment(t, 0.80, 1.0),
        );
        final double scrim =
            1 - TempoCurve.exit.transform(_segment(t, 0.86, 1.0));
        final double words = TempoCurve.entrance.transform(
          _segment(t, 0.40, 0.72),
        );
        final double tagline = TempoCurve.entrance.transform(
          _segment(t, 0.60, 0.82),
        );
        final double wordsOut =
            1 - TempoCurve.exit.transform(_segment(t, 0.80, 0.90));

        return IgnorePointer(
          ignoring: t > 0.9,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Size size = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final Offset centre = Offset(
                size.width / 2,
                size.height / 2 - 34,
              );
              // The mark travels from the centre of the window to its seat in
              // the sidebar, shrinking on the way. The path bows a little
              // upward so it reads as a flight, not a slide.
              final Offset home = LaunchScreen.markHome;
              final Offset straight = Offset.lerp(centre, home, handover)!;
              final double bow = math.sin(handover * math.pi) * -48;
              final Offset at = straight + Offset(0, bow);
              final double markSize = lerpDoubleSafe(
                LaunchScreen.markSize,
                LaunchScreen.markHomeSize,
                handover,
              );

              return Stack(
                children: <Widget>[
                  // The veil: nearly opaque at first, so the drifting room is
                  // felt rather than seen, dissolving as the app arrives.
                  Positioned.fill(
                    child: ColoredBox(
                      color: c.backdrop.withValues(alpha: 0.94 * scrim),
                    ),
                  ),
                  // A soft light behind the mark, breathing in with it.
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _Halo(
                        centre: centre,
                        colors: c,
                        intensity: theme.accentIntensity,
                        strength:
                            TempoCurve.entrance.transform(
                              _segment(t, 0.10, 0.62),
                            ) *
                            (1 - handover),
                      ),
                    ),
                  ),
                  // The wordmark and the line under it.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: centre.dy + LaunchScreen.markSize / 2 + 26,
                    child: Opacity(
                      opacity: (words * wordsOut).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - words)),
                        child: Column(
                          children: <Widget>[
                            ShaderMask(
                              shaderCallback: (Rect bounds) =>
                                  theme.accentWideGradient.createShader(bounds),
                              blendMode: BlendMode.srcIn,
                              child: Text(
                                AppInfo.name.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamilyFallback: TempoTypography.family,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w300,
                                  // The letters draw together as they land.
                                  letterSpacing: 16 - 6 * words,
                                  color: const Color(0xFFFFFFFF),
                                ),
                              ),
                            ),
                            const SizedBox(height: TempoSpace.sm),
                            Opacity(
                              opacity: tagline,
                              child: Transform.translate(
                                offset: Offset(0, 8 * (1 - tagline)),
                                child: Text(
                                  AppInfo.tagline,
                                  textAlign: TextAlign.center,
                                  style: context.typo.bodyMedium?.copyWith(
                                    color: c.textSecondary,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // The mark itself, drawing in and then flying home.
                  Positioned(
                    left: at.dx - markSize / 2,
                    top: at.dy - markSize / 2,
                    width: markSize,
                    height: markSize,
                    child: CustomPaint(
                      painter: _LaunchMark(
                        outer: TempoCurve.entrance.transform(
                          _segment(t, 0.02, 0.44),
                        ),
                        inner: TempoCurve.entrance.transform(
                          _segment(t, 0.20, 0.58),
                        ),
                        point: TempoCurve.entrance.transform(
                          _segment(t, 0.46, 0.64),
                        ),
                        bloom: _segment(t, 0.50, 0.86),
                        settle: handover,
                        colors: c,
                        intensity: theme.accentIntensity,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static double lerpDoubleSafe(double a, double b, double t) => a + (b - a) * t;
}

/// The Tempo mark, drawn by hand so each part can arrive in turn. The
/// geometry is the sidebar mark's exactly, so the flight ends on a match.
class _LaunchMark extends CustomPainter {
  const _LaunchMark({
    required this.outer,
    required this.inner,
    required this.point,
    required this.bloom,
    required this.settle,
    required this.colors,
    required this.intensity,
  });

  /// How much of the outer orbit has been drawn.
  final double outer;

  /// How much of the inner arc has been drawn.
  final double inner;

  /// The travelling point landing.
  final double point;

  /// A ring of light leaving the point once it has landed.
  final double bloom;

  /// The flight home: the glow is put away so the mark matches its seat.
  final double settle;

  final TempoColors colors;
  final double intensity;

  static const double _outerStart = math.pi * -0.62;
  static const double _outerSweep = math.pi * 1.62;
  static const double _innerStart = math.pi * 0.42;
  static const double _innerSweep = math.pi * 1.16;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 32.0;
    canvas.save();
    canvas.scale(scale);

    const Offset centre = Offset(16, 16);
    final Rect ringRect = Rect.fromCircle(center: centre, radius: 13);

    if (outer > 0) {
      final Paint ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: <Color>[
            colors.accent,
            colors.accentAlt,
            colors.accentSoft,
            colors.accent,
          ],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(ringRect);
      canvas.drawArc(ringRect, _outerStart, _outerSweep * outer, false, ring);
    }

    if (inner > 0) {
      final Rect innerRect = Rect.fromCircle(center: centre, radius: 7.2);
      final Paint arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors.accentSoft, colors.accent],
        ).createShader(innerRect);
      canvas.drawArc(innerRect, _innerStart, _innerSweep * inner, false, arc);
    }

    if (point > 0) {
      final Offset dot =
          centre + Offset(math.cos(_outerStart), math.sin(_outerStart)) * 13;
      // The point arrives from slightly beyond its seat and settles onto it.
      final double landing = 1 + 0.9 * (1 - point);
      canvas.drawCircle(
        dot,
        4.6 * point,
        Paint()..color = colors.accentSoft.withValues(alpha: 0.22 * point),
      );
      canvas.drawCircle(
        dot,
        2.7 * landing * point,
        Paint()..color = colors.accentSoft,
      );

      if (bloom > 0 && bloom < 1 && settle < 1) {
        // One ring of light leaves the point and fades as it grows.
        final double ease = Curves.easeOutCubic.transform(bloom);
        canvas.drawCircle(
          dot,
          4 + 22 * ease,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = colors.accentSoft.withValues(
              alpha: ((1 - ease) * 0.55 * intensity * (1 - settle)).clamp(
                0.0,
                1.0,
              ),
            ),
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LaunchMark old) =>
      old.outer != outer ||
      old.inner != inner ||
      old.point != point ||
      old.bloom != bloom ||
      old.settle != settle ||
      old.intensity != intensity ||
      old.colors.accent != colors.accent;
}

/// The light behind the mark: two of the product colours, soft and wide,
/// breathing in as the mark draws and put away as it leaves.
class _Halo extends CustomPainter {
  const _Halo({
    required this.centre,
    required this.colors,
    required this.intensity,
    required this.strength,
  });

  final Offset centre;
  final TempoColors colors;
  final double intensity;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) {
      return;
    }
    final double reach = math.min(size.width, size.height) * 0.42;
    void light(Offset at, double radius, Color color, double alpha) {
      canvas.drawCircle(
        at,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              color.withValues(
                alpha: (alpha * strength * intensity).clamp(0.0, 1.0),
              ),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: at, radius: radius)),
      );
    }

    light(
      centre.translate(-reach * 0.18, -reach * 0.12),
      reach,
      colors.accent,
      0.22,
    );
    light(
      centre.translate(reach * 0.22, reach * 0.16),
      reach * 0.9,
      colors.accentAlt,
      0.18,
    );
  }

  @override
  bool shouldRepaint(covariant _Halo old) =>
      old.strength != strength ||
      old.centre != centre ||
      old.intensity != intensity ||
      old.colors.accent != colors.accent;
}

/// Brings a part of the shell in as the launch hands over: it fades up and
/// slides the last few points into place, timed to the mark's flight. Once
/// the launch is done it costs nothing — the child is returned as it is.
class LaunchArrival extends StatelessWidget {
  const LaunchArrival({super.key, required this.slide, required this.child});

  /// Where the child starts relative to its seat; it slides from there to zero.
  final Offset slide;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: launchDone,
      builder: (BuildContext context, bool done, Widget? _) {
        if (done) {
          return child;
        }
        return ValueListenableBuilder<double>(
          valueListenable: launchReveal,
          builder: (BuildContext context, double r, Widget? inner) => Opacity(
            opacity: r.clamp(0.0, 1.0),
            child: Transform.translate(offset: slide * (1 - r), child: inner),
          ),
          child: child,
        );
      },
    );
  }
}
