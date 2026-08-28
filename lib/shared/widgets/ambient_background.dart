import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/window_effects.dart';
import '../../core/motion/tempo_motion.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_theme.dart';

/// How far the page in front has been scrolled, 0 at the top and 1 once it has
/// travelled far enough for the room behind it to have finished shifting.
///
/// Held globally because exactly one room exists, and because it must not
/// rebuild anything above it to move.
final ValueNotifier<double> ambientScrollDepth = ValueNotifier<double>(0);

/// Where the room is in its slow loop, 0 to 1. Every glass edge in the app
/// turns from this same number, which is what makes the cards and the lights
/// behind them read as one weather rather than many clocks.
final ValueNotifier<double> ambientPhase = ValueNotifier<double>(0);

/// The room the app lives in.
///
/// A base gradient, four very soft light blobs that drift on a slow loop, and
/// a vignette. Painted with radial gradients only, so there is no blur filter
/// and no texture: it stays smooth at 2560x1440 and costs one repaint layer.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TempoDuration.ambient,
  )..addListener(_publish);

  void _publish() => ambientPhase.value = _controller.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TempoMotion.reduced(context)) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_publish)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TempoTheme theme = context.tempo;
    return RepaintBoundary(
      child: ValueListenableBuilder<bool>(
        valueListenable: windowEffectActive,
        builder: (BuildContext context, bool translucent, Widget? _) =>
            AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                _controller,
                ambientScrollDepth,
              ]),
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: _AmbientPainter(
                    t: _controller.value,
                    colors: theme.colors,
                    intensity: theme.accentIntensity,
                    isDark: theme.isDark,
                    // With a system material behind the window, the room is
                    // painted as a wash rather than a wall, so the desktop
                    // reads through it without the text losing its footing.
                    opacity: translucent ? (theme.isDark ? 0.82 : 0.90) : 1,
                    depth: ambientScrollDepth.value,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter({
    required this.t,
    required this.colors,
    required this.intensity,
    required this.isDark,
    this.opacity = 1,
    this.depth = 0,
  });

  final double t;
  final TempoColors colors;
  final double intensity;
  final bool isDark;

  /// How solid the base wash is. Below one, the window's own material shows
  /// through it.
  final double opacity;

  /// How far the page in front has scrolled. The lights drift against it,
  /// which is what gives the window a sense of depth while reading.
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.backdrop.withValues(alpha: opacity),
            colors.backdropEdge.withValues(alpha: opacity),
          ],
        ).createShader(rect),
    );

    final double scale = isDark ? 1.0 : 0.55;
    // Each light rises against the page by a different amount — near ones
    // more, far ones less — which is what reads as depth rather than a slide.
    Alignment shifted(Alignment at, double factor) =>
        Alignment(at.x, at.y - depth * factor);

    _blob(canvas, size, shifted(const Alignment(-0.78, -0.88), 0.10), 0.62,
        colors.accent, 0.20 * scale, 0.00);
    _blob(canvas, size, shifted(const Alignment(0.86, -0.62), 0.16), 0.54,
        colors.accentAlt, 0.18 * scale, 0.33);
    _blob(canvas, size, shifted(const Alignment(0.18, 0.96), 0.28), 0.70,
        colors.accentSoft, 0.13 * scale, 0.61);
    _blob(canvas, size, shifted(const Alignment(-0.92, 0.74), 0.22), 0.46,
        colors.accent, 0.10 * scale, 0.84);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.92,
          colors: <Color>[
            colors.backdropEdge.withValues(alpha: 0),
            colors.backdropEdge.withValues(alpha: isDark ? 0.55 : 0.30),
          ],
          stops: const <double>[0.52, 1.0],
        ).createShader(rect),
    );
  }

  void _blob(
    Canvas canvas,
    Size size,
    Alignment base,
    double radiusFactor,
    Color color,
    double alpha,
    double phase,
  ) {
    final double angle = (t + phase) * 2 * math.pi;
    final Offset centre =
        base.alongSize(size) +
        Offset(
          math.sin(angle) * size.width * 0.035,
          math.cos(angle * 0.8) * size.height * 0.045,
        );
    final double radius = size.shortestSide * radiusFactor;
    final Rect bounds = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..blendMode = isDark ? BlendMode.plus : BlendMode.srcOver
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: (alpha * intensity).clamp(0.0, 1.0)),
            color.withValues(alpha: 0),
          ],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.intensity != intensity ||
      oldDelegate.isDark != isDark ||
      oldDelegate.opacity != opacity ||
      oldDelegate.depth != depth ||
      oldDelegate.colors.backdrop != colors.backdrop;
}
