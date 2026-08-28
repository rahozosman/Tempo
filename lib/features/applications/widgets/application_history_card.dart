import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/utilities/tempo_format.dart';
import '../../../domain/analytics/usage_aggregate.dart';
import '../../../shared/widgets/charts/tempo_bar_chart.dart';
import '../../../shared/widgets/glass/glass_card.dart';
import '../../../shared/widgets/glass/glass_segmented.dart';

/// The per-application history chart: one bar per day, over the last week or
/// the last thirty days.
class ApplicationHistoryCard extends StatefulWidget {
  const ApplicationHistoryCard({super.key, required this.series});

  /// Up to thirty days, oldest first.
  final List<DayValue> series;

  @override
  State<ApplicationHistoryCard> createState() => _ApplicationHistoryCardState();
}

class _ApplicationHistoryCardState extends State<ApplicationHistoryCard> {
  int _span = 7;

  @override
  Widget build(BuildContext context) {
    final List<DayValue> series = widget.series;
    final int span = _span > series.length ? series.length : _span;
    final List<DayValue> shown = series.sublist(series.length - span);
    final bool dense = span > 10;

    return GlassCard(
      hoverLift: false,
      padding: const EdgeInsets.all(TempoSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('HISTORY', style: context.typo.labelSmall),
              ),
              SizedBox(
                width: 210,
                child: TempoSegmented<int>(
                  value: _span,
                  onChanged: (int value) => setState(() => _span = value),
                  segments: const <TempoSegment<int>>[
                    TempoSegment<int>(value: 7, label: '7 days'),
                    TempoSegment<int>(value: 30, label: '30 days'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          TempoBarChart(
            height: 216,
            barWidth: dense ? 14 : 28,
            data: <BarDatum>[
              for (int i = 0; i < shown.length; i++)
                BarDatum(
                  label: _labelFor(shown, i, dense),
                  amount: shown[i].value.inSeconds.toDouble(),
                  highlighted: i == shown.length - 1,
                  tooltip:
                      '${TempoFormat.dayLong(shown[i].date)}\n'
                      '${TempoFormat.hm(shown[i].value)}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Dense charts only label every fifth day, plus today, so the axis stays
  /// readable instead of turning into a wall of numbers.
  static String _labelFor(List<DayValue> series, int index, bool dense) {
    final DateTime date = series[index].date;
    if (!dense) {
      return TempoFormat.weekdayShort(date);
    }
    final int fromEnd = series.length - 1 - index;
    if (fromEnd == 0 || fromEnd % 5 == 0) {
      return DateFormat.d().format(date);
    }
    return '';
  }
}
