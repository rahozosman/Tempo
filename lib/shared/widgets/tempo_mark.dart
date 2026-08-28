import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_theme.dart';

/// The Tempo identity: an open orbit with a single travelling point.
///
/// Time, motion and focus in one mark, drawn in the product gradient. No
/// lettering, so it works at 16pt in the tray and at 512pt as an app icon.
class TempoMark extends StatelessWidget {
  const TempoMark({super.key, this.size = 30, this.glow = true});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final Widget mark = CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(colors: c),
    );
    if (!glow) {
      return mark;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: context.tempo.accentGlow(0.7),
      ),
      child: mark,
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.colors});

  final TempoColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 32.0;
    canvas.save();
    canvas.scale(scale);

    const Offset centre = Offset(16, 16);
    final Rect ringRect = Rect.fromCircle(center: centre, radius: 13);

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

    // Open outer orbit.
    canvas.drawArc(ringRect, math.pi * -0.62, math.pi * 1.62, false, ring);

    // Inner counter arc, the second hand of the mark.
    final Rect innerRect = Rect.fromCircle(center: centre, radius: 7.2);
    final Paint inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[colors.accentSoft, colors.accent],
      ).createShader(innerRect);
    canvas.drawArc(innerRect, math.pi * 0.42, math.pi * 1.16, false, inner);

    // The travelling point.
    const double angle = math.pi * -0.62;
    final Offset dot = centre + Offset(math.cos(angle), math.sin(angle)) * 13;
    canvas.drawCircle(dot, 2.7, Paint()..color = colors.accentSoft);
    canvas.drawCircle(
      dot,
      4.6,
      Paint()..color = colors.accentSoft.withValues(alpha: 0.22),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.colors.accent != colors.accent ||
      oldDelegate.colors.accentAlt != colors.accentAlt ||
      oldDelegate.colors.accentSoft != colors.accentSoft;
}
