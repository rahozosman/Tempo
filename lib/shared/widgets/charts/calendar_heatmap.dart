import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion/tempo_animations.dart';
import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_heat.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/utilities/tempo_dates.dart';
import '../../../core/utilities/tempo_format.dart';
import '../../../domain/analytics/day_summary.dart';

/// A month laid out as a calendar, every day shaded by how long the computer
/// was used. Weeks run Monday to Sunday.
///
/// The grid never stretches: cells stop growing at [maxCellSize] and the whole
/// month centres itself, so a wide window gets a calendar rather than seven
/// enormous squares. Days arrive in a diagonal wave, today wears a ring, and
/// days still to come are drawn quieter than days that were simply quiet.
class CalendarHeatmap extends StatelessWidget {
  const CalendarHeatmap({
    super.key,
    required this.month,
    required this.days,
    required this.peak,
    this.selected,
    this.onSelect,
    this.spacing = 7,
    this.maxCellSize = 54,
  });

  /// The first of the month.
  final DateTime month;

  /// Every day of the month, first to last.
  final List<DaySummary> days;

  /// The busiest day of the month, which sets the top of the scale.
  final Duration peak;

  final DateTime? selected;
  final ValueChanged<DaySummary>? onSelect;
  final double spacing;
  final double maxCellSize;

  /// 1 January 2024 was a Monday, so weekday names can be read off it.
  static final DateTime _referenceMonday = DateTime(2024, 1);

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final DateTime today = TempoDates.startOfDay(DateTime.now());
    final int blanks = month.weekday - DateTime.monday;
    final int rows = ((blanks + days.length) / 7).ceil();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cell = math.min(
          maxCellSize,
          (constraints.maxWidth - spacing * 6) / 7,
        );
        final double width = cell * 7 + spacing * 6;

        return Align(
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    for (int i = 0; i < 7; i++) ...<Widget>[
                      if (i > 0) SizedBox(width: spacing),
                      SizedBox(
                        width: cell,
                        child: Center(
                          child: Text(
                            TempoFormat.weekdayShort(
                              DateTime(
                                _referenceMonday.year,
                                _referenceMonday.month,
                                _referenceMonday.day + i,
                              ),
                            ).substring(0, 2).toUpperCase(),
                            style: context.typo.labelSmall?.copyWith(
                              fontSize: 10,
                              letterSpacing: 1.2,
                              color: i >= 5 ? c.textTertiary : c.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: spacing + 3),
                for (int row = 0; row < rows; row++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: row == rows - 1 ? 0 : spacing,
                    ),
                    child: Row(
                      children: <Widget>[
                        for (int column = 0; column < 7; column++) ...<Widget>[
                          if (column > 0) SizedBox(width: spacing),
                          SizedBox(
                            width: cell,
                            height: cell,
                            child: _cellFor(
                              row: row,
                              column: column,
                              blanks: blanks,
                              today: today,
                              size: cell,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cellFor({
    required int row,
    required int column,
    required int blanks,
    required DateTime today,
    required double size,
  }) {
    final int dayIndex = row * 7 + column - blanks;
    if (dayIndex < 0 || dayIndex >= days.length) {
      return const SizedBox.shrink();
    }
    final DaySummary day = days[dayIndex];
    final double fraction = peak.inSeconds <= 0
        ? 0
        : day.total.inSeconds / peak.inSeconds;
    return _HeatCell(
      day: day,
      level: TempoHeat.levelOf(fraction),
      isToday: day.date.isAtSameMomentAs(today),
      isFuture: day.date.isAfter(today),
      isSelected: selected != null && day.date.isAtSameMomentAs(selected!),
      onTap: onSelect == null ? null : () => onSelect!(day),
      size: size,
      // A diagonal wave: the month settles from its first day outwards.
      index: row + column,
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.day,
    required this.level,
    required this.isToday,
    required this.isFuture,
    required this.isSelected,
    required this.index,
    required this.size,
    this.onTap,
  });

  final DaySummary day;
  final int level;
  final bool isToday;
  final bool isFuture;
  final bool isSelected;
  final int index;
  final double size;
  final VoidCallback? onTap;

  String get _tooltip {
    if (isFuture) {
      return '${TempoFormat.dayLong(day.date)}\nStill to come';
    }
    if (day.isEmpty) {
      return '${TempoFormat.dayLong(day.date)}\nNothing recorded';
    }
    final String top = day.topApp?.name ?? 'No application recorded';
    return '${TempoFormat.dayLong(day.date)}\n'
        '${TempoFormat.hm(day.total)} screen time\n'
        'Top: $top\n'
        '${TempoFormat.count(day.sessions, 'session')}';
  }

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final Color fill = isFuture
        ? c.textTertiary.withValues(alpha: 0.05)
        : TempoHeat.fill(c, level);
    final bool roomForTime = size >= 42 && !day.isEmpty && !isFuture;

    return TempoEntrance(
      index: index,
      rise: 8,
      duration: TempoDuration.slow,
      child: Tooltip(
        message: _tooltip,
        waitDuration: const Duration(milliseconds: 220),
        child: HoverBuilder(
          onTap: isFuture ? null : onTap,
          builder: (BuildContext context, bool hovered) => AnimatedContainer(
            duration: TempoMotion.of(context, TempoDuration.quick),
            curve: TempoCurve.gentle,
            transform: Matrix4.translationValues(0, hovered ? -2 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.28),
              color: hovered ? Color.lerp(fill, c.textPrimary, 0.16) : fill,
              border: Border.all(
                color: isSelected
                    ? c.textPrimary
                    : (isToday
                          ? c.accentSoft
                          : (isFuture
                                ? c.border.withValues(alpha: 0.4)
                                : TempoHeat.border(c, level))),
                width: isSelected ? 2 : (isToday ? 1.6 : 1),
              ),
              boxShadow: isSelected || (hovered && level > 0)
                  ? context.tempo.glowOf(
                      level == 0 ? c.accent : fill,
                      isSelected ? 1 : 0.6,
                    )
                  : null,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${day.date.day}',
                    style: context.typo.labelMedium?.copyWith(
                      fontSize: size >= 40 ? 13 : 11,
                      height: 1.05,
                      color: isFuture
                          ? c.textTertiary
                          : TempoHeat.ink(c, level),
                      fontWeight: isToday || isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  if (roomForTime)
                    Text(
                      TempoFormat.hm(day.total),
                      maxLines: 1,
                      style: context.typo.labelSmall?.copyWith(
                        fontSize: 8.5,
                        letterSpacing: 0.2,
                        height: 1.2,
                        color: TempoHeat.ink(
                          c,
                          level,
                        ).withValues(alpha: level >= 3 ? 0.85 : 0.62),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
