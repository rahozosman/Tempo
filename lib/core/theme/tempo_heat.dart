import 'package:flutter/material.dart';

import 'tempo_colors.dart';
import 'tempo_metrics.dart';
import 'tempo_theme.dart';

/// The intensity scale shared by the month calendar and the year activity
/// grid: four steps from a quiet blue to a lit violet, plus an empty step for
/// days with nothing recorded.
///
/// Steps are used rather than a continuous ramp so a legend can explain the
/// scale and so two adjacent days are always distinguishable.
class TempoHeat {
  const TempoHeat._();

  static const int steps = 4;

  /// [fraction] is the day measured against the busiest day of the period.
  static int levelOf(double fraction) {
    if (fraction <= 0) {
      return 0;
    }
    if (fraction < 0.25) {
      return 1;
    }
    if (fraction < 0.5) {
      return 2;
    }
    if (fraction < 0.75) {
      return 3;
    }
    return 4;
  }

  static Color fill(TempoColors c, int level) => switch (level) {
    0 => c.textTertiary.withValues(alpha: 0.12),
    1 => c.accent.withValues(alpha: 0.32),
    2 => c.accent.withValues(alpha: 0.66),
    3 => c.accentAlt,
    _ => c.accentSoft,
  };

  static Color border(TempoColors c, int level) => level == 0
      ? c.border
      : fill(c, level).withValues(alpha: 0.55);

  /// Readable ink for a day number drawn on top of the fill.
  static Color ink(TempoColors c, int level) =>
      level >= 3 ? const Color(0xFFFFFFFF) : c.textSecondary;
}

/// The "less to more" key that sits beside any heat grid.
class HeatLegend extends StatelessWidget {
  const HeatLegend({super.key, this.size = 11});

  final double size;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('Less', style: context.typo.bodySmall?.copyWith(fontSize: 11)),
        const SizedBox(width: TempoSpace.xs),
        for (int level = 0; level <= TempoHeat.steps; level++) ...<Widget>[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: TempoHeat.fill(c, level),
              border: Border.all(color: TempoHeat.border(c, level)),
            ),
          ),
          const SizedBox(width: 3),
        ],
        const SizedBox(width: TempoSpace.xxs),
        Text('More', style: context.typo.bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}
