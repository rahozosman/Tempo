import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/tempo_animations.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/utilities/tempo_dates.dart';
import '../../core/utilities/tempo_format.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/analytics/home_overview.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/awaiting_data.dart';
import '../../shared/widgets/charts/activity_ring.dart';
import '../../shared/widgets/charts/tempo_bar_chart.dart';
import '../../shared/widgets/charts/usage_row.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/live_clock.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/stats/animated_duration.dart';
import '../../shared/widgets/stats/delta_chip.dart';
import '../../shared/widgets/stats/metric_card.dart';
import '../../shared/widgets/stats/metric_grid.dart';
import '../../shared/widgets/tempo_icon.dart';
import '../applications/applications_controller.dart';
import '../navigation/nav_destination.dart';
import '../navigation/navigation_controller.dart';

/// Home. The day in one figure, the week around it, and the applications
/// behind the number.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeOverview> overview = ref.watch(homeOverviewProvider);
    final DateTime now = DateTime.now();

    return PageScaffold(
      title: TempoDates.greeting(now),
      subtitle: TempoDates.longDate(now),
      trailing: const LiveClock(),
      child: overview.when(
        loading: () => const PageLoading(),
        error: (Object error, StackTrace stack) => ErrorStateView(
          title: 'Unable to read your history',
          message:
              'Tempo could not open its usage database. Restarting the app '
              'usually clears this.',
          detail: error,
        ),
        data: (HomeOverview data) => data.isEmpty
            ? const AwaitingData(
                glyph: TempoGlyph.home,
                title: 'Your day starts here',
                message:
                    'Home shows how long you were at the computer today, how '
                    'that compares with last week, and where the hours went.',
              )
            : _HomeBody(overview: data),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.overview});

  final HomeOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DaySummary today = overview.today;
    void openApplications() => ref
        .read(navigationProvider.notifier)
        .selectSection(TempoSection.applications);

    return ListView(
      padding: const EdgeInsets.only(bottom: TempoSpace.xl),
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget hero = _HeroCard(overview: overview);
            final Widget week = _WeekCard(overview: overview);
            if (constraints.maxWidth < 920) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  hero,
                  const SizedBox(height: TempoSpace.md),
                  week,
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(flex: 5, child: hero),
                  const SizedBox(width: TempoSpace.md),
                  Expanded(flex: 4, child: week),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(
          index: 1,
          child: MetricGrid(
            children: <Widget>[
              MetricCard(
                label: 'Active',
                glyph: TempoGlyph.play,
                value: AnimatedDuration(
                  value: today.active,
                  style: context.typo.headlineLarge,
                ),
                caption:
                    '${TempoFormat.percent(today.activeShare)} of screen time',
                footer: SplitBar(fraction: today.activeShare),
              ),
              MetricCard(
                label: 'Idle',
                glyph: TempoGlyph.pause,
                tone: context.colors.accentAlt,
                value: AnimatedDuration(
                  value: today.idle,
                  style: context.typo.headlineLarge,
                ),
                caption: 'Awake, but untouched',
              ),
              MetricCard(
                label: 'Sessions',
                glyph: TempoGlyph.apps,
                tone: context.colors.accentSoft,
                value: AnimatedCount(
                  value: today.sessions,
                  style: context.typo.headlineLarge,
                ),
                caption:
                    'Averaging ${TempoFormat.hm(today.averageSession)} each',
              ),
              MetricCard(
                label: 'Longest stretch',
                glyph: TempoGlyph.insights,
                value: AnimatedDuration(
                  value: today.longestSession,
                  style: context.typo.headlineLarge,
                ),
                caption: 'Your longest unbroken run today',
              ),
            ],
          ),
        ),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(
          index: 2,
          child: _ApplicationsCard(
            today: today,
            onSeeAll: openApplications,
            onOpen: (AppUsage usage) => openApplication(ref, usage),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.overview});

  final HomeOverview overview;

  @override
  Widget build(BuildContext context) {
    final DaySummary today = overview.today;
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
                  'YOUR SCREEN TIME',
                  style: context.typo.labelSmall,
                ),
              ),
              DeltaChip(
                change: overview.weekChange,
                caption: 'vs last week',
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          Center(
            child: ActivityRing(
              active: today.active,
              idle: today.idle,
              size: 248,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AnimatedDuration(
                      value: today.total,
                      style: context.typo.displayMedium,
                    ),
                    const SizedBox(height: TempoSpace.xxs),
                    Text('today', style: context.typo.labelSmall),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: TempoSpace.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _RingLegend(
                  label: 'Active',
                  value: today.active,
                  gradient: true,
                ),
              ),
              Expanded(
                child: _RingLegend(
                  label: 'Idle',
                  value: today.idle,
                  gradient: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingLegend extends StatelessWidget {
  const _RingLegend({
    required this.label,
    required this.value,
    required this.gradient,
  });

  final String label;
  final Duration value;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient ? context.tempo.accentGradient : null,
            color: gradient ? null : c.textSecondary.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(width: TempoSpace.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typo.bodyMedium,
          ),
        ),
        const SizedBox(width: TempoSpace.xs),
        Text(
          TempoFormat.hm(value),
          maxLines: 1,
          style: context.typo.labelLarge?.copyWith(color: c.textPrimary),
        ),
      ],
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.overview});

  final HomeOverview overview;

  @override
  Widget build(BuildContext context) {
    final List<DaySummary> days = overview.lastSevenDays;
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
                  'LAST SEVEN DAYS',
                  style: context.typo.labelSmall,
                ),
              ),
              Text(
                TempoFormat.hm(overview.weekTotal),
                style: context.typo.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          TempoBarChart(
            height: 216,
            data: <BarDatum>[
              for (int i = 0; i < days.length; i++)
                BarDatum(
                  label: TempoFormat.weekdayShort(days[i].date),
                  amount: days[i].total.inSeconds.toDouble(),
                  highlighted: i == days.length - 1,
                  tooltip:
                      '${TempoFormat.dayLong(days[i].date)}\n'
                      '${TempoFormat.hm(days[i].total)} screen time',
                ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _WeekStat(
                  label: 'Daily average',
                  value: TempoFormat.hm(overview.dailyAverage),
                ),
              ),
              Expanded(
                child: _WeekStat(
                  label: 'Previous seven',
                  value: TempoFormat.hm(overview.previousWeekTotal),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekStat extends StatelessWidget {
  const _WeekStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label.toUpperCase(), style: context.typo.labelSmall),
        const SizedBox(height: TempoSpace.xxs),
        Text(value, style: context.typo.titleMedium),
      ],
    );
  }
}

class _ApplicationsCard extends StatelessWidget {
  const _ApplicationsCard({
    required this.today,
    required this.onSeeAll,
    required this.onOpen,
  });

  final DaySummary today;
  final VoidCallback onSeeAll;
  final ValueChanged<AppUsage> onOpen;

  @override
  Widget build(BuildContext context) {
    final List<AppUsage> apps = today.topApps(5);
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
                    'TODAY’S APPLICATIONS',
                    style: context.typo.labelSmall,
                  ),
                ),
                GlassButton(
                  label: 'See all',
                  style: GlassButtonStyle.quiet,
                  compact: true,
                  onPressed: onSeeAll,
                ),
              ],
            ),
          ),
          const SizedBox(height: TempoSpace.sm),
          if (apps.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TempoSpace.sm,
                TempoSpace.xs,
                TempoSpace.sm,
                TempoSpace.md,
              ),
              child: Text(
                'Nothing recorded yet today.',
                style: context.typo.bodyMedium,
              ),
            )
          else
            for (int i = 0; i < apps.length; i++)
              UsageRow(
                usage: apps[i],
                total: today.active,
                index: i,
                onTap: () => onOpen(apps[i]),
              ),
        ],
      ),
    );
  }
}
