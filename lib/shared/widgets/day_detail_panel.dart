import 'package:flutter/material.dart';

import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/utilities/tempo_format.dart';
import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/day_summary.dart';
import 'charts/day_timeline.dart';
import 'charts/usage_row.dart';
import 'glass/glass_button.dart';
import 'glass/glass_card.dart';
import 'tempo_icon.dart';

/// One day opened from a calendar or an activity grid: its totals, its shape
/// hour by hour, and the applications behind it.
class DayDetailPanel extends StatelessWidget {
  const DayDetailPanel({
    super.key,
    required this.day,
    this.onClose,
    this.onOpenApplication,
  });

  final DaySummary day;
  final VoidCallback? onClose;

  /// Called when one of the day's applications is chosen.
  final ValueChanged<AppUsage>? onOpenApplication;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final List<AppUsage> apps = day.topApps(4);

    return GlassCard(
      hoverLift: false,
      padding: const EdgeInsets.all(TempoSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      TempoFormat.dayLong(day.date),
                      style: context.typo.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.isEmpty
                          ? 'Nothing recorded on this day'
                          : '${TempoFormat.count(day.sessions, 'session')}  ·  '
                                'longest ${TempoFormat.hm(day.longestSession)}',
                      style: context.typo.bodySmall,
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                GlassIconButton(
                  glyph: TempoGlyph.close,
                  tooltip: 'Close',
                  size: 30,
                  onPressed: onClose,
                ),
            ],
          ),
          if (!day.isEmpty) ...<Widget>[
            const SizedBox(height: TempoSpace.lg),
            Row(
              children: <Widget>[
                _MiniStat(label: 'Screen time', value: day.total),
                _MiniStat(
                  label: 'Active',
                  value: day.active,
                  tone: c.accentAlt,
                ),
                _MiniStat(
                  label: 'Idle',
                  value: day.idle,
                  tone: c.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: TempoSpace.lg),
            DayTimeline(minutesByHour: day.activeMinutesByHour, height: 96),
            if (apps.isNotEmpty) ...<Widget>[
              const SizedBox(height: TempoSpace.md),
              for (int i = 0; i < apps.length; i++)
                UsageRow(
                  usage: apps[i],
                  total: day.active,
                  index: i,
                  showTrend: false,
                  onTap: onOpenApplication == null
                      ? null
                      : () => onOpenApplication!(apps[i]),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.tone});

  final String label;
  final Duration value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Expanded(
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: tone ?? c.accent,
            ),
          ),
          const SizedBox(width: TempoSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label.toUpperCase(), style: context.typo.labelSmall),
              const SizedBox(height: 2),
              Text(
                TempoFormat.hm(value),
                style: context.typo.titleMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
