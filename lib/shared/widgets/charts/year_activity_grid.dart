import 'dart:math' as math;

import 'package:flutter/material.dart';
// intl ships its own TextDirection; the painter wants the dart:ui one.
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_heat.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/utilities/tempo_dates.dart';
import '../../../core/utilities/tempo_format.dart';
import '../../../domain/analytics/day_summary.dart';
import '../glass/glass_surface.dart';

/// A whole year of activity: one small square per day, columns running week by
/// week, shaded by how long the computer was used.
///
/// The grid is painted as a single layer rather than several hundred widgets,
/// so a year stays cheap to draw and to animate. Hovering is resolved from the
/// pointer position, and the card that follows the cursor is a real widget so
/// it can use the product typography.
class YearActivityGrid extends StatefulWidget {
  const YearActivityGrid({
    super.key,
    required this.year,
    required this.days,
    required this.peak,
    this.selected,
    this.onSelect,
  });

  final int year;

  /// Every day of the year, 1 January first. 365 entries, or 366.
  final List<DaySummary> days;

  /// The busiest day, which sets the top of the scale.
  final Duration peak;

  final DateTime? selected;
  final ValueChanged<DaySummary>? onSelect;

  @override
  State<YearActivityGrid> createState() => _YearActivityGridState();
}

class _YearActivityGridState extends State<YearActivityGrid>
    with SingleTickerProviderStateMixin {
  static const double _gap = 3;
  static const double _labelWidth = 30;
  static const double _headerHeight = 20;
  static const double _cardWidth = 236;
  static const double _cardHeight = 128;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  int? _hovered;
  Offset _pointer = Offset.zero;

  // Geometry from the last layout, used to resolve pointer positions.
  double _cell = 12;
  int _columns = 53;
  int _lead = 0;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (TempoMotion.reduced(context)) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
  }

  @override
  void didUpdateWidget(covariant YearActivityGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year && !TempoMotion.reduced(context)) {
      _hovered = null;
      _reveal.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  int? _indexAt(Offset local) {
    final double x = local.dx - _labelWidth;
    final double y = local.dy - _headerHeight;
    if (x < 0 || y < 0) {
      return null;
    }
    final int column = x ~/ (_cell + _gap);
    final int row = y ~/ (_cell + _gap);
    if (column < 0 || column >= _columns || row < 0 || row > 6) {
      return null;
    }
    final int index = column * 7 + row - _lead;
    if (index < 0 || index >= widget.days.length) {
      return null;
    }
    return index;
  }

  void _onHover(PointerEvent event) {
    final int? index = _indexAt(event.localPosition);
    if (index == _hovered) {
      if (index != null) {
        setState(() => _pointer = event.localPosition);
      }
      return;
    }
    setState(() {
      _hovered = index;
      _pointer = event.localPosition;
    });
  }

  void _onExit(PointerEvent event) {
    if (_hovered != null) {
      setState(() => _hovered = null);
    }
  }

  void _onTap(TapUpDetails details) {
    final int? index = _indexAt(details.localPosition);
    if (index != null) {
      widget.onSelect?.call(widget.days[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final DateTime first = DateTime(widget.year);
    _lead = first.weekday - DateTime.monday;
    _columns = ((_lead + widget.days.length) / 7).ceil();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double available = constraints.maxWidth - _labelWidth;
        _cell = ((available - (_columns - 1) * _gap) / _columns).clamp(
          7.0,
          18.0,
        );
        final double width =
            _labelWidth + _columns * _cell + (_columns - 1) * _gap;
        final double height = _headerHeight + 7 * _cell + 6 * _gap;
        final DaySummary? hoveredDay = _hovered == null
            ? null
            : widget.days[_hovered!];

        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              MouseRegion(
                onHover: _onHover,
                onExit: _onExit,
                cursor: widget.onSelect == null
                    ? MouseCursor.defer
                    : SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _onTap,
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _reveal,
                      builder: (BuildContext context, Widget? child) =>
                          CustomPaint(
                            size: Size(width, height),
                            painter: _YearPainter(
                              days: widget.days,
                              year: widget.year,
                              peak: widget.peak,
                              colors: c,
                              intensity: context.tempo.accentIntensity,
                              progress: _reveal.value,
                              hovered: _hovered,
                              selected: widget.selected,
                              today: TempoDates.startOfDay(DateTime.now()),
                              lead: _lead,
                              columns: _columns,
                              cell: _cell,
                              gap: _gap,
                              labelWidth: _labelWidth,
                              headerHeight: _headerHeight,
                              labelStyle:
                                  context.typo.bodySmall?.copyWith(
                                    fontSize: 10.5,
                                    color: c.textTertiary,
                                  ) ??
                                  const TextStyle(),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
              if (hoveredDay != null)
                Positioned(
                  left: (_pointer.dx + 16).clamp(
                    0.0,
                    math.max(0.0, constraints.maxWidth - _cardWidth),
                  ),
                  top: _pointer.dy > _cardHeight + 8
                      ? _pointer.dy - _cardHeight - 8
                      : _pointer.dy + 18,
                  child: IgnorePointer(
                    child: _DayCard(day: hoveredDay, width: _cardWidth),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The card that follows the pointer across the grid.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.width});

  final DaySummary day;
  final double width;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return GlassSurface(
      width: width,
      radius: TempoRadius.md,
      fill: c.surfaceElevated.withValues(alpha: 0.97),
      padding: const EdgeInsets.all(TempoSpace.sm + 2),
      shadows: context.tempo.panelShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            TempoFormat.dayLong(day.date),
            style: context.typo.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: TempoSpace.xs),
          if (day.isEmpty)
            Text('Nothing recorded', style: context.typo.bodySmall)
          else ...<Widget>[
            _CardLine(
              label: 'Screen time',
              value: TempoFormat.hm(day.total),
              emphasised: true,
            ),
            _CardLine(
              label: 'Top app',
              value: day.topApp?.name ?? '—',
            ),
            _CardLine(
              label: 'Sessions',
              value: '${day.sessions}',
            ),
          ],
        ],
      ),
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: context.typo.bodySmall?.copyWith(fontSize: 11.5),
            ),
          ),
          const SizedBox(width: TempoSpace.xs),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: emphasised
                  ? context.typo.labelLarge?.copyWith(
                      color: context.colors.textPrimary,
                    )
                  : context.typo.bodySmall?.copyWith(
                      fontSize: 11.5,
                      color: context.colors.textPrimary,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearPainter extends CustomPainter {
  const _YearPainter({
    required this.days,
    required this.year,
    required this.peak,
    required this.colors,
    required this.intensity,
    required this.progress,
    required this.hovered,
    required this.selected,
    required this.today,
    required this.lead,
    required this.columns,
    required this.cell,
    required this.gap,
    required this.labelWidth,
    required this.headerHeight,
    required this.labelStyle,
  });

  final List<DaySummary> days;
  final int year;
  final Duration peak;
  final TempoColors colors;
  final double intensity;
  final double progress;
  final int? hovered;
  final DateTime? selected;
  final DateTime today;
  final int lead;
  final int columns;
  final double cell;
  final double gap;
  final double labelWidth;
  final double headerHeight;
  final TextStyle labelStyle;

  static final DateTime _referenceMonday = DateTime(2024, 1);

  Offset _originOf(int index) {
    final int position = lead + index;
    final int column = position ~/ 7;
    final int row = position % 7;
    return Offset(
      labelWidth + column * (cell + gap),
      headerHeight + row * (cell + gap),
    );
  }

  void _text(Canvas canvas, String value, Offset at, {bool centreY = false}) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: value, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centreY ? Offset(at.dx, at.dy - painter.height / 2) : at,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Month names above the column each month starts in, read off the day list
    // rather than calculated, and skipping any that would land on top of the
    // one before it.
    int lastLabelColumn = -10;
    for (int index = 0; index < days.length; index++) {
      if (days[index].date.day != 1) {
        continue;
      }
      final int column = (lead + index) ~/ 7;
      if (column - lastLabelColumn < 3) {
        continue;
      }
      lastLabelColumn = column;
      _text(
        canvas,
        DateFormat.MMM().format(days[index].date),
        Offset(_originOf(index).dx, 0),
      );
    }

    // Monday, Wednesday and Friday only: enough to read the grid without
    // crowding it.
    for (final int row in <int>[0, 2, 4]) {
      _text(
        canvas,
        DateFormat.E().format(
          DateTime(
            _referenceMonday.year,
            _referenceMonday.month,
            _referenceMonday.day + row,
          ),
        ),
        Offset(0, headerHeight + row * (cell + gap) + cell / 2),
        centreY: true,
      );
    }

    final double radius = math.max(2, cell * 0.26);
    final int peakSeconds = peak.inSeconds;

    for (int index = 0; index < days.length; index++) {
      final DaySummary day = days[index];
      final int column = (lead + index) ~/ 7;
      final double columnProgress = Interval(
        (column / columns * 0.5).clamp(0.0, 0.5),
        1,
        curve: TempoCurve.entrance,
      ).transform(progress);
      if (columnProgress <= 0.001) {
        continue;
      }

      final double fraction = peakSeconds <= 0
          ? 0
          : day.total.inSeconds / peakSeconds;
      final int level = TempoHeat.levelOf(fraction);
      final bool isHovered = hovered == index;
      final bool isSelected =
          selected != null && day.date.isAtSameMomentAs(selected!);
      final bool isToday = day.date.isAtSameMomentAs(today);

      final Offset origin = _originOf(index);
      final double inset = (1 - columnProgress) * cell * 0.32;
      final Rect rect = Rect.fromLTWH(
        origin.dx + inset,
        origin.dy + inset,
        cell - inset * 2,
        cell - inset * 2,
      );
      final RRect rounded = RRect.fromRectAndRadius(
        rect,
        Radius.circular(radius),
      );

      Color fill = TempoHeat.fill(colors, level);
      if (isHovered) {
        fill = Color.lerp(fill, colors.textPrimary, 0.22)!;
      }
      canvas.drawRRect(
        rounded,
        Paint()..color = fill.withValues(alpha: fill.a * columnProgress),
      );

      if (level >= 3 && intensity > 0.6 && !isHovered) {
        // The heaviest days carry a whisper of their own colour around them.
        canvas.drawRRect(
          rounded.inflate(1.2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = fill.withValues(
              alpha: (0.18 * intensity * columnProgress).clamp(0.0, 1.0),
            ),
        );
      }

      if (isSelected || isToday || isHovered) {
        canvas.drawRRect(
          rounded,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 1.8 : 1.4
            ..color = isSelected
                ? colors.textPrimary
                : (isToday
                      ? colors.accentSoft
                      : colors.textPrimary.withValues(alpha: 0.55)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _YearPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.hovered != hovered ||
      oldDelegate.selected != selected ||
      oldDelegate.days != days ||
      oldDelegate.cell != cell ||
      oldDelegate.colors.accent != colors.accent ||
      oldDelegate.intensity != intensity;
}
