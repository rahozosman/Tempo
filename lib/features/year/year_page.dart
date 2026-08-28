import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/motion/tempo_animations.dart';
import '../../core/theme/tempo_heat.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/utilities/tempo_dates.dart';
import '../../core/utilities/tempo_format.dart';
import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/analytics/year_summary.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/awaiting_data.dart';
import '../../shared/widgets/charts/tempo_bar_chart.dart';
import '../../shared/widgets/charts/year_activity_grid.dart';
import '../../shared/widgets/day_detail_panel.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/insight_card.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/period_stepper.dart';
import '../../shared/widgets/stats/animated_duration.dart';
import '../../shared/widgets/stats/delta_chip.dart';
import '../../shared/widgets/stats/metric_card.dart';
import '../../shared/widgets/stats/metric_grid.dart';
import '../../shared/widgets/tempo_icon.dart';
import '../applications/applications_controller.dart';
import 'year_controller.dart';
import 'year_insights.dart';

/// The year: every day as one square, the months behind it, and what the data
/// can honestly say about the twelve months.
class YearPage extends ConsumerWidget {
  const YearPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int year = ref.watch(selectedYearProvider);
    final AsyncValue<YearSummary> summary = ref.watch(yearSummaryProvider);
    final List<int> years =
        ref.watch(availableYearsProvider).value ?? <int>[year];
    final SelectedYearController controller = ref.read(
      selectedYearProvider.notifier,
    );

    final int earliest = years.isEmpty ? year : years.first;
    final int latest = years.isEmpty ? year : years.last;
    final int current = DateTime.now().year;
    final int dayCount = TempoDates.daysInYear(year);

    return PageScaffold(
      title: '$year',
      subtitle: TempoDates.isLeapYear(year)
          ? '$dayCount days · a leap year'
          : '$dayCount days, one square each',
      trailing: PeriodStepper(
        label: '$year',
        width: 96,
        resetLabel: 'This year',
        onPrevious: year > earliest ? controller.previous : null,
        onNext: year < latest ? controller.next : null,
        onReset: year == current ? null : controller.reset,
      ),
      child: summary.when(
        loading: () => const PageLoading(),
        error: (Object error, StackTrace stack) => ErrorStateView(
          title: 'Unable to read $year',
          message:
              'Tempo could not open its usage database. Restarting the app '
              'usually clears this.',
          detail: error,
        ),
        data: (YearSummary data) {
          if (!data.isEmpty) {
            return _YearBody(summary: data);
          }
          if (year == current) {
            return const AwaitingData(
              glyph: TempoGlyph.year,
              title: 'No usage data yet this year',
              message:
                  'Every day of the year becomes a square, shaded by screen '
                  'time. Hover one for the detail, open one for that day in '
                  'full.',
            );
          }
          return EmptyState(
            glyph: TempoGlyph.year,
            title: 'No usage data for $year',
            message:
                'Nothing was recorded in $year. Use the arrows above to look '
                'at another year.',
          );
        },
      ),
    );
  }
}

class _YearBody extends ConsumerWidget {
  const _YearBody({required this.summary});

  final YearSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUsage? mostUsed = summary.mostUsed;
    final DaySummary? busiest = summary.busiest;
    final DaySummary? longestDay = summary.longestSessionDay;
    final DateTime? selectedDate = ref.watch(yearDayProvider);
    final List<InsightLine> insights = buildYearInsights(summary);

    DaySummary? selected;
    if (selectedDate != null) {
      for (final DaySummary day in summary.days) {
        if (day.date.isAtSameMomentAs(selectedDate)) {
          selected = day;
          break;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: TempoSpace.xl),
      children: <Widget>[
        MetricGrid(
          maxPerRow: 3,
          children: <Widget>[
            MetricCard(
              label: 'Screen time',
              glyph: TempoGlyph.clock,
              value: AnimatedDuration(
                value: summary.screenTime,
                style: context.typo.headlineLarge,
              ),
              caption:
                  '${TempoFormat.count(summary.activeDays, 'day')} with '
                  'activity',
              footer: DeltaChip(
                change: summary.totalChange,
                caption: 'vs ${summary.year - 1}',
                compact: true,
              ),
            ),
            MetricCard(
              label: 'Average per day',
              glyph: TempoGlyph.today,
              tone: context.colors.accentAlt,
              value: AnimatedDuration(
                value: summary.dailyAverage,
                style: context.typo.headlineLarge,
              ),
              caption: 'On days with activity',
            ),
            MetricCard(
              label: 'Most used',
              glyph: TempoGlyph.apps,
              tone: context.colors.accentSoft,
              value: Text(
                mostUsed?.name ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typo.headlineMedium,
              ),
              caption: mostUsed == null
                  ? 'No application recorded'
                  : '${TempoFormat.hm(mostUsed.duration)} · '
                        '${TempoFormat.percent(mostUsed.shareOf(summary.activeTime))} '
                        'of active time',
              onTap: mostUsed == null
                  ? null
                  : () => openApplication(ref, mostUsed),
            ),
            MetricCard(
              label: 'Most active day',
              glyph: TempoGlyph.insights,
              value: Text(
                busiest == null
                    ? '—'
                    : TempoFormat.dayShort(busiest.date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typo.headlineMedium,
              ),
              caption: busiest == null
                  ? 'Nothing recorded yet'
                  : '${TempoFormat.hm(busiest.total)} of screen time',
              onTap: busiest == null
                  ? null
                  : () =>
                        ref.read(yearDayProvider.notifier).select(busiest.date),
            ),
            MetricCard(
              label: 'Longest session',
              glyph: TempoGlyph.play,
              tone: context.colors.accentAlt,
              value: AnimatedDuration(
                value: summary.longestSession,
                style: context.typo.headlineLarge,
              ),
              caption: longestDay == null
                  ? 'Nothing recorded yet'
                  : 'On ${TempoFormat.dayShort(longestDay.date)}',
            ),
            MetricCard(
              label: 'Active days',
              glyph: TempoGlyph.year,
              tone: context.colors.accentSoft,
              value: AnimatedCount(
                value: summary.activeDays,
                style: context.typo.headlineLarge,
              ),
              caption: 'Of ${summary.dayCount} days in ${summary.year}',
            ),
          ],
        ),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(index: 1, child: _ActivityCard(summary: summary)),
        if (selected != null) ...<Widget>[
          const SizedBox(height: TempoSpace.md),
          TempoEntrance(
            key: ValueKey<DateTime>(selected.date),
            child: DayDetailPanel(
              day: selected,
              onClose: ref.read(yearDayProvider.notifier).clear,
              onOpenApplication: (AppUsage usage) =>
                  openApplication(ref, usage),
            ),
          ),
        ],
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(index: 2, child: _MonthlyCard(summary: summary)),
        if (insights.isNotEmpty) ...<Widget>[
          const SizedBox(height: TempoSpace.lg),
          Padding(
            padding: const EdgeInsets.only(
              left: TempoSpace.xxs,
              bottom: TempoSpace.sm,
            ),
            child: Text(
              'WHAT ${summary.year} LOOKED LIKE',
              style: context.typo.labelSmall,
            ),
          ),
          MetricGrid(
            maxPerRow: 2,
            children: <Widget>[
              for (final InsightLine insight in insights)
                InsightCard(
                  glyph: insight.glyph,
                  headline: insight.headline,
                  detail: insight.detail,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ActivityCard extends ConsumerWidget {
  const _ActivityCard({required this.summary});

  final YearSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                child: Text(
                  'ACTIVITY IN ${summary.year}',
                  style: context.typo.labelSmall,
                ),
              ),
              const HeatLegend(),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          YearActivityGrid(
            year: summary.year,
            days: summary.days,
            peak: summary.peak,
            selected: ref.watch(yearDayProvider),
            onSelect: (DaySummary day) =>
                ref.read(yearDayProvider.notifier).select(day.date),
          ),
          const SizedBox(height: TempoSpace.md),
          Text(
            'Hover a day for the detail. Click one to open it below.',
            style: context.typo.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MonthlyCard extends StatelessWidget {
  const _MonthlyCard({required this.summary});

  final YearSummary summary;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final int currentMonth = now.year == summary.year ? now.month : 0;

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
                child: Text('BY MONTH', style: context.typo.labelSmall),
              ),
              Text(
                '${summary.year - 1} behind each bar',
                style: context.typo.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          TempoBarChart(
            height: 200,
            barWidth: 34,
            data: <BarDatum>[
              for (int month = 0; month < 12; month++)
                BarDatum(
                  label: DateFormat.MMM().format(
                    DateTime(summary.year, month + 1),
                  ),
                  amount: summary.monthlyTotals[month].inSeconds.toDouble(),
                  ghost: summary.previousMonthlyTotals[month].inSeconds
                      .toDouble(),
                  highlighted: month + 1 == currentMonth,
                  tooltip:
                      '${DateFormat.MMMM().format(DateTime(summary.year, month + 1))} '
                      '${summary.year}\n'
                      '${TempoFormat.hm(summary.monthlyTotals[month])}\n'
                      '${summary.year - 1}: ${TempoFormat.hm(summary.previousMonthlyTotals[month])}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}
