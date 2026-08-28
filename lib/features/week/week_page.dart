import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/tempo_animations.dart';
import '../../core/motion/tempo_motion.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/utilities/tempo_dates.dart';
import '../../core/utilities/tempo_format.dart';
import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/analytics/week_summary.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/awaiting_data.dart';
import '../../shared/widgets/charts/tempo_bar_chart.dart';
import '../../shared/widgets/charts/usage_row.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_segmented.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/period_stepper.dart';
import '../../shared/widgets/stats/animated_duration.dart';
import '../../shared/widgets/stats/delta_chip.dart';
import '../../shared/widgets/stats/metric_card.dart';
import '../../shared/widgets/stats/metric_grid.dart';
import '../../shared/widgets/tempo_icon.dart';
import '../applications/applications_controller.dart';
import '../applications/widgets/category_card.dart';
import 'week_controller.dart';

/// The week: seven days measured three ways, against the week before it.
class WeekPage extends ConsumerWidget {
  const WeekPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int offset = ref.watch(weekOffsetProvider);
    final AsyncValue<WeekSummary> summary = ref.watch(weekSummaryProvider);
    final WeekOffsetController stepper = ref.read(
      weekOffsetProvider.notifier,
    );
    final DateTime start = weekStartFor(offset);

    return PageScaffold(
      title: offset == 0
          ? 'This Week'
          : 'Week of ${TempoFormat.monthDay(start)}',
      subtitle: TempoDates.weekRange(start),
      trailing: PeriodStepper(
        label: TempoDates.weekRangeShort(start),
        width: 132,
        resetLabel: 'This week',
        onPrevious: stepper.previous,
        onNext: offset < 0 ? stepper.next : null,
        onReset: offset == 0 ? null : stepper.reset,
      ),
      child: summary.when(
        loading: () => const PageLoading(),
        error: (Object error, StackTrace stack) => ErrorStateView(
          title: 'Unable to read this week',
          message:
              'Tempo could not open its usage database. Restarting the app '
              'usually clears this.',
          detail: error,
        ),
        data: (WeekSummary data) => data.isEmpty
            ? const AwaitingData(
                glyph: TempoGlyph.week,
                title: 'No days recorded this week',
                message:
                    'Seven days, one bar each, with the daily average, the '
                    'longest session and how the week compares with the one '
                    'before it.',
              )
            : _WeekBody(summary: data),
      ),
    );
  }
}

class _WeekBody extends ConsumerWidget {
  const _WeekBody({required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUsage? mostUsed = summary.mostUsed;
    final DaySummary? busiest = summary.busiestDay;

    return ListView(
      padding: const EdgeInsets.only(bottom: TempoSpace.xl),
      children: <Widget>[
        MetricGrid(
          children: <Widget>[
            MetricCard(
              label: 'Screen time',
              glyph: TempoGlyph.clock,
              value: AnimatedDuration(
                value: summary.screenTime,
                style: context.typo.headlineLarge,
              ),
              caption:
                  '${TempoFormat.count(summary.recordedDays, 'day')} with '
                  'activity',
              footer: DeltaChip(
                change: summary.change,
                caption: 'vs last week',
                compact: true,
              ),
            ),
            MetricCard(
              label: 'Daily average',
              glyph: TempoGlyph.today,
              tone: context.colors.accentAlt,
              value: AnimatedDuration(
                value: summary.dailyAverage,
                style: context.typo.headlineLarge,
              ),
              caption: 'Across the days with activity',
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
              label: 'Longest session',
              glyph: TempoGlyph.insights,
              value: AnimatedDuration(
                value: summary.longestSession,
                style: context.typo.headlineLarge,
              ),
              caption: busiest == null
                  ? 'Nothing recorded yet'
                  : 'Busiest day ${TempoFormat.dayShort(busiest.date)} · '
                        '${TempoFormat.hm(busiest.total)}',
            ),
          ],
        ),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(index: 1, child: _WeekChartCard(summary: summary)),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(index: 2, child: _ComparisonCard(summary: summary)),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(
          index: 3,
          child: CategoryCard(
            apps: summary.apps,
            title: 'Where the week went',
          ),
        ),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(index: 4, child: _WeekApplicationsCard(summary: summary)),
      ],
    );
  }
}

class _WeekChartCard extends ConsumerWidget {
  const _WeekChartCard({required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WeekMeasure measure = ref.watch(weekMeasureProvider);
    final DateTime today = TempoDates.startOfDay(DateTime.now());
    final List<DaySummary> days = summary.days;
    final List<DaySummary> previous = summary.previousDays;

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
                child: Text('THE WEEK', style: context.typo.labelSmall),
              ),
              SizedBox(
                width: 320,
                child: TempoSegmented<WeekMeasure>(
                  value: measure,
                  onChanged: ref.read(weekMeasureProvider.notifier).set,
                  segments: <TempoSegment<WeekMeasure>>[
                    for (final WeekMeasure value in WeekMeasure.values)
                      TempoSegment<WeekMeasure>(
                        value: value,
                        label: value.label,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.sm),
          Row(
            children: <Widget>[
              const _ChartKey(label: 'This week', solid: true),
              const SizedBox(width: TempoSpace.md),
              const _ChartKey(label: 'Last week', solid: false),
              const Spacer(),
              Text(
                measure.describe(_totalOf(days, measure)),
                style: context.typo.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          TempoBarChart(
            height: 236,
            data: <BarDatum>[
              for (int i = 0; i < days.length; i++)
                BarDatum(
                  label: TempoFormat.weekdayShort(days[i].date),
                  amount: measure.amountOf(days[i]),
                  ghost: i < previous.length
                      ? measure.amountOf(previous[i])
                      : null,
                  highlighted: days[i].date.isAtSameMomentAs(today),
                  tooltip:
                      '${TempoFormat.dayLong(days[i].date)}\n'
                      '${measure.describe(measure.amountOf(days[i]))}\n'
                      'Last week: ${i < previous.length ? measure.describe(measure.amountOf(previous[i])) : '—'}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  static double _totalOf(List<DaySummary> days, WeekMeasure measure) {
    double total = 0;
    for (final DaySummary day in days) {
      total += measure.amountOf(day);
    }
    return total;
  }
}

class _ChartKey extends StatelessWidget {
  const _ChartKey({required this.label, required this.solid});

  final String label;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: solid ? context.tempo.accentGradient : null,
            color: solid ? null : c.textSecondary.withValues(alpha: 0.22),
          ),
        ),
        const SizedBox(width: TempoSpace.xs),
        Text(label, style: context.typo.bodySmall),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final int now = summary.screenTime.inSeconds;
    final int before = summary.previousScreenTime.inSeconds;
    final int peak = now > before ? now : before;
    final Duration difference = Duration(seconds: (now - before).abs());

    return GlassCard(
      hoverLift: false,
      padding: const EdgeInsets.all(TempoSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('AGAINST LAST WEEK', style: context.typo.labelSmall),
          const SizedBox(height: TempoSpace.lg),
          _ComparisonRow(
            label: 'This week',
            value: summary.screenTime,
            fraction: peak <= 0 ? 0 : now / peak,
            emphasised: true,
          ),
          const SizedBox(height: TempoSpace.md),
          _ComparisonRow(
            label: 'Last week',
            value: summary.previousScreenTime,
            fraction: peak <= 0 ? 0 : before / peak,
            emphasised: false,
          ),
          const SizedBox(height: TempoSpace.lg),
          Text(
            before <= 0
                ? 'There is no screen time recorded for last week to compare '
                      'against.'
                : now >= before
                ? '${TempoFormat.hm(difference)} more than last week.'
                : '${TempoFormat.hm(difference)} less than last week.',
            style: context.typo.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.emphasised,
  });

  final String label;
  final Duration value;
  final double fraction;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: context.typo.bodyMedium?.copyWith(
              color: emphasised ? c.textPrimary : c.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: TempoSpace.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: 14,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(color: c.glassFill.withValues(alpha: 0.09)),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: fraction.clamp(0.0, 1.0),
                    ),
                    duration: TempoMotion.of(
                      context,
                      const Duration(milliseconds: 950),
                    ),
                    curve: TempoCurve.entrance,
                    builder:
                        (BuildContext context, double t, Widget? child) =>
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: t,
                              child: child,
                            ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        gradient: emphasised
                            ? context.tempo.accentGradient
                            : null,
                        color: emphasised
                            ? null
                            : c.textSecondary.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: TempoSpace.md),
        SizedBox(
          width: 78,
          child: Text(
            TempoFormat.hm(value),
            textAlign: TextAlign.right,
            style: context.typo.titleSmall?.copyWith(
              color: emphasised ? c.textPrimary : c.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekApplicationsCard extends ConsumerWidget {
  const _WeekApplicationsCard({required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AppUsage> apps = summary.apps.length > 6
        ? summary.apps.sublist(0, 6)
        : summary.apps;

    return GlassCard(
      hoverLift: false,
      padding: const EdgeInsets.fromLTRB(
        TempoSpace.lg,
        TempoSpace.lg,
        TempoSpace.lg,
        TempoSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TempoSpace.sm),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'APPLICATIONS THIS WEEK',
                    style: context.typo.labelSmall,
                  ),
                ),
                Text(
                  TempoFormat.count(summary.apps.length, 'application'),
                  style: context.typo.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: TempoSpace.sm),
          for (int i = 0; i < apps.length; i++)
            UsageRow(
              usage: apps[i],
              total: summary.activeTime,
              index: i,
              onTap: () => openApplication(ref, apps[i]),
            ),
        ],
      ),
    );
  }
}
