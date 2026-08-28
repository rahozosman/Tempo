import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/motion/tempo_animations.dart';
import '../../core/motion/tempo_motion.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_heat.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/utilities/tempo_dates.dart';
import '../../core/utilities/tempo_format.dart';
import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/analytics/month_summary.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/awaiting_data.dart';
import '../../shared/widgets/charts/calendar_heatmap.dart';
import '../../shared/widgets/charts/tempo_bar_chart.dart';
import '../../shared/widgets/day_detail_panel.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/period_stepper.dart';
import '../../shared/widgets/stats/animated_duration.dart';
import '../../shared/widgets/stats/delta_chip.dart';
import '../../shared/widgets/stats/metric_card.dart';
import '../../shared/widgets/stats/metric_grid.dart';
import '../../shared/widgets/tempo_icon.dart';
import '../applications/applications_controller.dart';
import '../applications/widgets/category_card.dart';
import 'month_controller.dart';

/// The month: a calendar you can read at a glance and open a day from, the
/// rhythm of the days beside it, and what the month was actually spent on.
class MonthPage extends ConsumerWidget {
  const MonthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int offset = ref.watch(monthOffsetProvider);
    final AsyncValue<MonthSummary> summary = ref.watch(monthSummaryProvider);
    final MonthOffsetController stepper = ref.read(
      monthOffsetProvider.notifier,
    );
    final DateTime month = monthStartFor(offset);

    return PageScaffold(
      title: offset == 0 ? 'This Month' : TempoDates.monthAndYear(month),
      subtitle: offset == 0
          ? TempoDates.monthAndYear(month)
          : 'Every day shaded by screen time',
      trailing: PeriodStepper(
        label: TempoDates.monthAndYear(month),
        resetLabel: 'This month',
        onPrevious: stepper.previous,
        onNext: offset < 0 ? stepper.next : null,
        onReset: offset == 0 ? null : stepper.reset,
      ),
      child: summary.when(
        loading: () => const PageLoading(),
        error: (Object error, StackTrace stack) => ErrorStateView(
          title: 'Unable to read this month',
          message:
              'Tempo could not open its usage database. Restarting the app '
              'usually clears this.',
          detail: error,
        ),
        data: (MonthSummary data) => data.isEmpty
            ? _EmptyMonth(summary: data)
            : _MonthBody(summary: data),
      ),
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return AwaitingData(
      glyph: TempoGlyph.month,
      title: 'No days recorded in ${TempoDates.monthAndYear(summary.month)}',
      message:
          'A calendar of the month with every day shaded by screen time, '
          'plus the quietest and busiest days.',
    );
  }
}

class _MonthBody extends ConsumerWidget {
  const _MonthBody({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUsage? mostUsed = summary.mostUsed;
    final DaySummary? busiest = summary.busiest;
    final DateTime? selectedDate = ref.watch(selectedDayProvider);
    final DaySummary? selected = selectedDate == null
        ? null
        : summary.dayOn(selectedDate);

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
                caption: 'vs last month',
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
              label: 'Busiest day',
              glyph: TempoGlyph.insights,
              value: Text(
                busiest == null ? '—' : TempoFormat.dayShort(busiest.date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typo.headlineMedium,
              ),
              caption: busiest == null
                  ? 'Nothing recorded yet'
                  : '${TempoFormat.hm(busiest.total)} of screen time',
              onTap: busiest == null
                  ? null
                  : () => ref
                        .read(selectedDayProvider.notifier)
                        .select(busiest.date),
            ),
          ],
        ),
        const SizedBox(height: TempoSpace.md),
        // The calendar and the day it opens, side by side on a wide window so
        // choosing a day never scrolls the calendar off the screen.
        TempoEntrance(
          index: 1,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget calendar = _CalendarCard(
                summary: summary,
                selected: selected,
              );
              final Widget day = _DayPanel(
                summary: summary,
                selected: selected,
              );
              if (constraints.maxWidth < 960) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    calendar,
                    const SizedBox(height: TempoSpace.md),
                    day,
                  ],
                );
              }
              // Deliberately not IntrinsicHeight: the calendar measures itself
              // with a LayoutBuilder, which cannot answer an intrinsic query.
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 5, child: calendar),
                  const SizedBox(width: TempoSpace.md),
                  Expanded(flex: 4, child: day),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(index: 2, child: _RhythmCard(summary: summary)),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(
          index: 3,
          child: CategoryCard(
            apps: summary.apps,
            title: 'Where the month went',
          ),
        ),
      ],
    );
  }
}

/// The calendar, and the two days worth naming underneath it.
class _CalendarCard extends ConsumerWidget {
  const _CalendarCard({required this.summary, required this.selected});

  final MonthSummary summary;
  final DaySummary? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TempoColors c = context.colors;
    final DaySummary? busiest = summary.busiest;
    final DaySummary? quietest = summary.quietest;

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
                  DateFormat('MMMM').format(summary.month).toUpperCase(),
                  style: context.typo.labelSmall,
                ),
              ),
              const HeatLegend(),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          // Keyed by month, so stepping through history redraws the grid
          // rather than mutating the one on screen.
          AnimatedSwitcher(
            duration: TempoMotion.of(context, TempoDuration.page),
            switchInCurve: TempoCurve.entrance,
            switchOutCurve: TempoCurve.exit,
            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[...previous, ?current],
            ),
            child: KeyedSubtree(
              key: ValueKey<DateTime>(summary.month),
              child: CalendarHeatmap(
                month: summary.month,
                days: summary.days,
                peak: summary.peak,
                selected: selected?.date,
                onSelect: (DaySummary day) =>
                    ref.read(selectedDayProvider.notifier).select(day.date),
              ),
            ),
          ),
          const SizedBox(height: TempoSpace.lg),
          Container(height: 1, color: c.border),
          const SizedBox(height: TempoSpace.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _DayNote(
                  label: 'Busiest',
                  day: busiest,
                  tone: c.accentSoft,
                  onTap: busiest == null
                      ? null
                      : () => ref
                            .read(selectedDayProvider.notifier)
                            .select(busiest.date),
                ),
              ),
              Expanded(
                child: _DayNote(
                  label: 'Lightest',
                  day: quietest,
                  tone: c.textSecondary,
                  onTap: quietest == null
                      ? null
                      : () => ref
                            .read(selectedDayProvider.notifier)
                            .select(quietest.date),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayNote extends StatelessWidget {
  const _DayNote({
    required this.label,
    required this.day,
    required this.tone,
    this.onTap,
  });

  final String label;
  final DaySummary? day;
  final Color tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final DaySummary? value = day;
    return HoverBuilder(
      onTap: onTap,
      builder: (BuildContext context, bool hovered) => Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: tone,
            ),
          ),
          const SizedBox(width: TempoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label.toUpperCase(), style: context.typo.labelSmall),
                const SizedBox(height: 1),
                AnimatedDefaultTextStyle(
                  duration: TempoMotion.of(context, TempoDuration.base),
                  curve: TempoCurve.gentle,
                  style:
                      context.typo.titleSmall?.copyWith(
                        color: hovered && onTap != null
                            ? context.colors.accentSoft
                            : context.colors.textPrimary,
                      ) ??
                      const TextStyle(),
                  child: Text(
                    value == null
                        ? '—'
                        : '${TempoFormat.dayShort(value.date)} · '
                              '${TempoFormat.hm(value.total)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Whatever day is open — the one chosen, or the busiest as a starting point.
class _DayPanel extends ConsumerWidget {
  const _DayPanel({required this.summary, required this.selected});

  final MonthSummary summary;
  final DaySummary? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DaySummary? day = selected ?? summary.busiest;
    if (day == null) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: TempoMotion.of(context, TempoDuration.base),
      switchInCurve: TempoCurve.entrance,
      switchOutCurve: TempoCurve.exit,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
      child: KeyedSubtree(
        key: ValueKey<DateTime>(day.date),
        child: DayDetailPanel(
          day: day,
          onClose: selected == null
              ? null
              : ref.read(selectedDayProvider.notifier).clear,
          onOpenApplication: (AppUsage usage) => openApplication(ref, usage),
        ),
      ),
    );
  }
}

/// The month as a row of days, and the weekday it leans on.
class _RhythmCard extends ConsumerWidget {
  const _RhythmCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime today = TempoDates.startOfDay(DateTime.now());
    final List<DaySummary> days = summary.days;
    final int? heaviest = summary.heaviestWeekday;
    final ({List<Duration> totals, List<int> counts}) week = summary.byWeekday;

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
                  'DAY BY DAY',
                  style: context.typo.labelSmall,
                ),
              ),
              if (heaviest != null)
                Flexible(
                  child: Text(
                    '${DateFormat.EEEE().format(DateTime(2024, 1, 1 + heaviest))}s '
                    'are heaviest · '
                    '${TempoFormat.hm(summary.weekdayAverage(heaviest))} on average',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: context.typo.bodySmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          TempoBarChart(
            height: 172,
            barWidth: 14,
            onSelected: (int index) => ref
                .read(selectedDayProvider.notifier)
                .select(days[index].date),
            data: <BarDatum>[
              for (int i = 0; i < days.length; i++)
                BarDatum(
                  // Only every fifth day is labelled, so the axis stays a
                  // rhythm rather than a wall of numbers.
                  label: (i + 1) % 5 == 0 || i == 0 ? '${days[i].date.day}' : '',
                  amount: days[i].total.inSeconds.toDouble(),
                  highlighted: days[i].date.isAtSameMomentAs(today),
                  tooltip:
                      '${TempoFormat.dayLong(days[i].date)}\n'
                      '${TempoFormat.hm(days[i].total)} screen time',
                ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          Row(
            children: <Widget>[
              for (int day = 0; day < 7; day++)
                Expanded(
                  child: _WeekdayAverage(
                    label: TempoFormat.weekdayShort(
                      DateTime(2024, 1, 1 + day),
                    ),
                    value: week.counts[day] == 0
                        ? Duration.zero
                        : Duration(
                            seconds:
                                week.totals[day].inSeconds ~/ week.counts[day],
                          ),
                    peak: _peakAverage(week),
                    emphasised: day == heaviest,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Duration _peakAverage(
    ({List<Duration> totals, List<int> counts}) week,
  ) {
    Duration peak = Duration.zero;
    for (int day = 0; day < 7; day++) {
      if (week.counts[day] == 0) {
        continue;
      }
      final Duration average = Duration(
        seconds: week.totals[day].inSeconds ~/ week.counts[day],
      );
      if (average > peak) {
        peak = average;
      }
    }
    return peak;
  }
}

/// One weekday's average for the month, as a quiet horizontal meter.
class _WeekdayAverage extends StatelessWidget {
  const _WeekdayAverage({
    required this.label,
    required this.value,
    required this.peak,
    required this.emphasised,
  });

  final String label;
  final Duration value;
  final Duration peak;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final double share = peak.inSeconds <= 0
        ? 0
        : (value.inSeconds / peak.inSeconds).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(right: TempoSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label.substring(0, 2).toUpperCase(),
            style: context.typo.labelSmall?.copyWith(
              fontSize: 10,
              color: emphasised ? c.accentSoft : c.textTertiary,
            ),
          ),
          const SizedBox(height: TempoSpace.xxs),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(color: c.glassFill.withValues(alpha: 0.09)),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: share),
                    duration: TempoMotion.of(
                      context,
                      const Duration(milliseconds: 900),
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
                        gradient: emphasised
                            ? context.tempo.accentGradient
                            : null,
                        color: emphasised
                            ? null
                            : c.accent.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: TempoSpace.xxs),
          Text(
            value == Duration.zero ? '—' : TempoFormat.hm(value),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: context.typo.bodySmall?.copyWith(
              fontSize: 10.5,
              color: emphasised ? c.textPrimary : c.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
