import 'package:flutter/material.dart';

import '../../core/theme/tempo_theme.dart';

/// The Tempo glyph set.
///
/// Icons are drawn as vectors on a 24x24 grid rather than pulled from a font,
/// so the whole app shares one stroke weight, one corner treatment and one
/// optical rhythm, and none of it looks like stock Material.
enum TempoGlyph {
  home,
  today,
  apps,
  week,
  month,
  year,
  insights,
  settings,
  play,
  pause,
  close,
  minimize,
  maximize,
  restore,
  chevronLeft,
  chevronRight,
  sparkle,
  clock,
  lock,
  info,
  trendUp,
  trendDown,
  plus,
}

class TempoIcon extends StatelessWidget {
  const TempoIcon(
    this.glyph, {
    super.key,
    this.size = 20,
    this.color,
    this.strokeWidth = 1.7,
  });

  final TempoGlyph glyph;
  final double size;
  final Color? color;

  /// Stroke weight expressed on the 24pt grid.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final Color resolved =
        color ?? IconTheme.of(context).color ?? const Color(0xFFFFFFFF);
    final double size = context.sized(this.size);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlyphPainter(
          glyph: glyph,
          color: resolved,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.glyph,
    required this.color,
    required this.strokeWidth,
  });

  final TempoGlyph glyph;
  final Color color;
  final double strokeWidth;

  static void _line(
    Canvas canvas,
    Paint paint,
    double x1,
    double y1,
    double x2,
    double y2,
  ) => canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);

  static void _rrect(
    Canvas canvas,
    Paint paint,
    double left,
    double top,
    double right,
    double bottom,
    double radius,
  ) => canvas.drawRRect(
    RRect.fromLTRBR(left, top, right, bottom, Radius.circular(radius)),
    paint,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24.0, size.height / 24.0);

    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint bold = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.55
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint thin = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (glyph) {
      case TempoGlyph.home:
        _rrect(canvas, stroke, 5.4, 11.0, 18.6, 20.4, 3.2);
        canvas.drawPath(
          Path()
            ..moveTo(3.4, 11.4)
            ..lineTo(12, 4.2)
            ..lineTo(20.6, 11.4),
          stroke,
        );
        break;
      case TempoGlyph.today:
        _rrect(canvas, stroke, 3.8, 5.4, 20.2, 20.4, 3.4);
        _line(canvas, stroke, 3.8, 9.8, 20.2, 9.8);
        _line(canvas, stroke, 8.2, 3.4, 8.2, 6.6);
        _line(canvas, stroke, 15.8, 3.4, 15.8, 6.6);
        canvas.drawCircle(const Offset(12, 15.4), 1.8, fill);
        break;
      case TempoGlyph.apps:
        _rrect(canvas, stroke, 4.2, 4.2, 10.8, 10.8, 2.4);
        _rrect(canvas, stroke, 13.2, 4.2, 19.8, 10.8, 2.4);
        _rrect(canvas, stroke, 4.2, 13.2, 10.8, 19.8, 2.4);
        _rrect(canvas, stroke, 13.2, 13.2, 19.8, 19.8, 2.4);
        break;
      case TempoGlyph.week:
        _line(canvas, bold, 5.4, 19.2, 5.4, 13.4);
        _line(canvas, bold, 9.8, 19.2, 9.8, 8.6);
        _line(canvas, bold, 14.2, 19.2, 14.2, 15.4);
        _line(canvas, bold, 18.6, 19.2, 18.6, 5.8);
        break;
      case TempoGlyph.month:
        _rrect(canvas, stroke, 3.6, 5.4, 20.4, 20.4, 3.4);
        _line(canvas, stroke, 3.6, 9.8, 20.4, 9.8);
        for (final double x in <double>[8.2, 12.0, 15.8]) {
          for (final double y in <double>[13.6, 17.0]) {
            canvas.drawCircle(Offset(x, y), 1.05, fill);
          }
        }
        break;
      case TempoGlyph.year:
        for (int col = 0; col < 4; col++) {
          for (int row = 0; row < 4; row++) {
            final double left = 3.6 + col * 4.4;
            final double top = 3.6 + row * 4.4;
            final bool active = (col + row) % 3 == 0;
            _rrect(
              canvas,
              active ? fill : thin,
              left,
              top,
              left + 3.4,
              top + 3.4,
              1.1,
            );
          }
        }
        break;
      case TempoGlyph.insights:
        canvas.drawPath(
          Path()
            ..moveTo(4.0, 16.8)
            ..lineTo(9.4, 11.2)
            ..lineTo(13.2, 14.4)
            ..lineTo(19.2, 6.8),
          stroke,
        );
        canvas.drawCircle(const Offset(19.2, 6.8), 1.9, fill);
        break;
      case TempoGlyph.settings:
        _line(canvas, stroke, 4.0, 7.6, 11.4, 7.6);
        _line(canvas, stroke, 16.6, 7.6, 20.0, 7.6);
        canvas.drawCircle(const Offset(14.0, 7.6), 2.3, stroke);
        _line(canvas, stroke, 4.0, 16.4, 7.4, 16.4);
        _line(canvas, stroke, 12.6, 16.4, 20.0, 16.4);
        canvas.drawCircle(const Offset(10.0, 16.4), 2.3, stroke);
        break;
      case TempoGlyph.play:
        canvas.drawPath(
          Path()
            ..moveTo(9.0, 6.2)
            ..lineTo(18.4, 12.0)
            ..lineTo(9.0, 17.8)
            ..close(),
          stroke,
        );
        break;
      case TempoGlyph.pause:
        _line(canvas, bold, 9.4, 6.6, 9.4, 17.4);
        _line(canvas, bold, 14.6, 6.6, 14.6, 17.4);
        break;
      case TempoGlyph.close:
        _line(canvas, stroke, 7.6, 7.6, 16.4, 16.4);
        _line(canvas, stroke, 16.4, 7.6, 7.6, 16.4);
        break;
      case TempoGlyph.minimize:
        _line(canvas, stroke, 6.8, 12.0, 17.2, 12.0);
        break;
      case TempoGlyph.maximize:
        _rrect(canvas, stroke, 6.8, 6.8, 17.2, 17.2, 2.2);
        break;
      case TempoGlyph.restore:
        _rrect(canvas, stroke, 4.8, 8.8, 15.2, 19.2, 2.0);
        canvas.drawPath(
          Path()
            ..moveTo(8.4, 8.0)
            ..lineTo(8.4, 6.4)
            ..lineTo(17.6, 6.4)
            ..lineTo(17.6, 15.6)
            ..lineTo(16.0, 15.6),
          stroke,
        );
        break;
      case TempoGlyph.chevronLeft:
        canvas.drawPath(
          Path()
            ..moveTo(14.2, 5.8)
            ..lineTo(8.8, 12.0)
            ..lineTo(14.2, 18.2),
          stroke,
        );
        break;
      case TempoGlyph.chevronRight:
        canvas.drawPath(
          Path()
            ..moveTo(9.8, 5.8)
            ..lineTo(15.2, 12.0)
            ..lineTo(9.8, 18.2),
          stroke,
        );
        break;
      case TempoGlyph.sparkle:
        canvas.drawPath(
          Path()
            ..moveTo(12.0, 3.4)
            ..quadraticBezierTo(13.2, 10.8, 20.6, 12.0)
            ..quadraticBezierTo(13.2, 13.2, 12.0, 20.6)
            ..quadraticBezierTo(10.8, 13.2, 3.4, 12.0)
            ..quadraticBezierTo(10.8, 10.8, 12.0, 3.4)
            ..close(),
          stroke,
        );
        break;
      case TempoGlyph.clock:
        canvas.drawCircle(const Offset(12, 12), 8.4, stroke);
        _line(canvas, stroke, 12.0, 12.0, 12.0, 7.4);
        _line(canvas, stroke, 12.0, 12.0, 15.4, 13.6);
        break;
      case TempoGlyph.lock:
        _rrect(canvas, stroke, 5.6, 10.6, 18.4, 20.2, 2.8);
        canvas.drawPath(
          Path()
            ..moveTo(8.4, 10.6)
            ..lineTo(8.4, 8.2)
            ..arcToPoint(
              const Offset(15.6, 8.2),
              radius: const Radius.circular(3.6),
            )
            ..lineTo(15.6, 10.6),
          stroke,
        );
        break;
      case TempoGlyph.info:
        canvas.drawCircle(const Offset(12, 12), 8.4, stroke);
        canvas.drawCircle(const Offset(12, 7.9), 1.05, fill);
        _line(canvas, stroke, 12.0, 11.4, 12.0, 16.6);
        break;
      case TempoGlyph.trendUp:
        canvas.drawPath(
          Path()
            ..moveTo(4.2, 16.6)
            ..lineTo(9.8, 11.0)
            ..lineTo(13.4, 14.4)
            ..lineTo(19.8, 7.6),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(15.0, 7.6)
            ..lineTo(19.8, 7.6)
            ..lineTo(19.8, 12.2),
          stroke,
        );
        break;
      case TempoGlyph.plus:
        _line(canvas, stroke, 12.0, 6.6, 12.0, 17.4);
        _line(canvas, stroke, 6.6, 12.0, 17.4, 12.0);
        break;
      case TempoGlyph.trendDown:
        canvas.drawPath(
          Path()
            ..moveTo(4.2, 7.4)
            ..lineTo(9.8, 13.0)
            ..lineTo(13.4, 9.6)
            ..lineTo(19.8, 16.4),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(15.0, 16.4)
            ..lineTo(19.8, 16.4)
            ..lineTo(19.8, 11.8),
          stroke,
        );
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
