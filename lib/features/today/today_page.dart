import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/tempo_animations.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/utilities/tempo_dates.dart';
import '../../core/utilities/tempo_format.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/tracking/usage_session.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/awaiting_data.dart';
import '../../shared/widgets/charts/activity_ring.dart';
import '../../shared/widgets/charts/day_timeline.dart';
import '../../shared/widgets/charts/session_timeline.dart';
import '../../shared/widgets/charts/usage_row.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/stats/animated_duration.dart';
import '../../shared/widgets/stats/metric_card.dart';
import '../../shared/widgets/stats/metric_grid.dart';
import '../../shared/widgets/tempo_icon.dart';
import '../applications/applications_controller.dart';
import '../applications/widgets/category_card.dart';
import '../applications/widgets/limits_card.dart';
import '../focus/focus_card.dart';
import '../settings/preferences_controller.dart';

/// Today in full: the totals, the shape of the day hour by hour, and every
/// application behind it.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DaySummary> summary = ref.watch(todaySummaryProvider);

    return PageScaffold(
      title: 'Today',
      subtitle: TempoDates.longDate(DateTime.now()),
      child: summary.when(
        loading: () => const PageLoading(),
        error: (Object error, StackTrace stack) => ErrorStateView(
          title: 'Unable to read today',
          message:
              'Tempo could not open its usage database. Restarting the app '
              'usually clears this.',
          detail: error,
        ),
        data: (DaySummary day) => day.isEmpty
            ? const AwaitingData(
                glyph: TempoGlyph.today,
                title: 'Nothing recorded today',
                message:
                    'Active time, idle time and every application you use '
                    'will be listed here as the day fills in.',
              )
            : _TodayBody(day: day),
      ),
    );
  }
}

class _TodayBody extends StatelessWidget {
  const _TodayBody({required this.day});

  final DaySummary day;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: TempoSpace.xl),
      children: <Widget>[
        MetricGrid(
          children: <Widget>[
            MetricCard(
              label: 'Screen time',
              glyph: TempoGlyph.clock,
              value: AnimatedDuration(
                value: day.total,
                style: context.typo.headlineLarge,
              ),
              caption: 'Active and idle together',
              footer: SplitBar(fraction: day.activeShare),
            ),
            MetricCard(
              label: 'Active',
              glyph: TempoGlyph.play,
              value: AnimatedDuration(
                value: day.active,
                style: context.typo.headlineLarge,
              ),
              caption:
                  '${TempoFormat.percent(day.activeShare)} of your screen time',
            ),
            MetricCard(
              label: 'Idle',
              glyph: TempoGlyph.pause,
              tone: context.colors.accentAlt,
              value: AnimatedDuration(
                value: day.idle,
                style: context.typo.headlineLarge,
              ),
              caption: 'Not counted towards any application',
            ),
            MetricCard(
              label: 'Sessions',
              glyph: TempoGlyph.apps,
              tone: context.colors.accentSoft,
              value: AnimatedCount(
                value: day.sessions,
                style: context.typo.headlineLarge,
              ),
              caption: 'Averaging ${TempoFormat.hm(day.averageSession)} each',
            ),
          ],
        ),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(index: 1, child: _GoalCard(day: day)),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(
          index: 2,
          child: GlassCard(
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
                        'HOUR BY HOUR',
                        style: context.typo.labelSmall,
                      ),
                    ),
                    Text(
                      'Longest stretch  ${TempoFormat.hm(day.longestSession)}',
                      style: context.typo.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: TempoSpace.lg),
                // The day as it happened, then the same day as a shape.
                _SessionStrip(date: day.date),
                const SizedBox(height: TempoSpace.lg),
                DayTimeline(minutesByHour: day.activeMinutesByHour, height: 86),
              ],
            ),
          ),
        ),
        const SizedBox(height: TempoSpace.md),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(index: 3, child: const FocusCard()),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(index: 4, child: LimitsCard(apps: day.apps)),
        TempoEntrance(
          index: 5,
          child: CategoryCard(
            apps: day.apps,
            title: 'Where the day went',
            caption: 'Set where an application belongs from its own page.',
          ),
        ),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(
          index: 6,
          child: _ApplicationsCard(day: day),
        ),
      ],
    );
  }
}

/// Today against the goal set in Settings. Passing it is stated plainly, not
/// scolded: the point is to know, not to feel watched.
class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.day});

  final DaySummary day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Duration goal = ref.watch(
      preferencesProvider.select(
        (TempoPreferences value) => value.dailyGoal,
      ),
    );
    final bool passed = day.total >= goal;
    final Duration difference = Duration(
      seconds: (day.total.inSeconds - goal.inSeconds).abs(),
    );
    final double share = goal.inSeconds <= 0
        ? 0
        : (day.total.inSeconds / goal.inSeconds).clamp(0.0, 1.0);

    return GlassCard(
      hoverLift: false,
      padding: const EdgeInsets.all(TempoSpace.xl),
      child: Row(
        children: <Widget>[
          ActivityRing(
            active: passed ? goal : day.total,
            idle: Duration.zero,
            reference: goal,
            size: 148,
            thickness: 11,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    TempoFormat.percent(share),
                    style: context.typo.headlineMedium,
                  ),
                  Text('of goal', style: context.typo.labelSmall),
                ],
              ),
            ),
          ),
          const SizedBox(width: TempoSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('DAILY GOAL', style: context.typo.labelSmall),
                const SizedBox(height: TempoSpace.sm),
                Text(
                  '${TempoFormat.hm(day.total)} / ${TempoFormat.hm(goal)}',
                  style: context.typo.headlineLarge,
                ),
                const SizedBox(height: TempoSpace.xs),
                Text(
                  passed
                      ? 'You have passed the goal for today by '
                            '${TempoFormat.hm(difference)}.'
                      : '${TempoFormat.hm(difference)} left before you reach '
                            'the goal for today.',
                  style: context.typo.bodyLarge,
                ),
                const SizedBox(height: TempoSpace.xxs),
                Text(
                  'Set your goal in Settings.',
                  style: context.typo.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationsCard extends ConsumerWidget {
  const _ApplicationsCard({required this.day});

  final DaySummary day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AppUsage> apps = day.topApps(8);
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
                    'APPLICATIONS',
                    style: context.typo.labelSmall,
                  ),
                ),
                Text(
                  TempoFormat.count(day.apps.length, 'application'),
                  style: context.typo.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: TempoSpace.sm),
          for (int i = 0; i < apps.length; i++)
            UsageRow(
              usage: apps[i],
              total: day.active,
              index: i,
              onTap: () => openApplication(ref, apps[i]),
            ),
        ],
      ),
    );
  }
}

/// The day's sessions, once they have been read.
class _SessionStrip extends ConsumerWidget {
  const _SessionStrip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<UsageSession> sessions =
        ref.watch(daySessionsProvider(date)).value ?? const <UsageSession>[];
    return SessionTimeline(
      sessions: sessions,
      date: date,
      onOpen: (UsageSession session) => openApplication(
        ref,
        AppUsage(
          id: session.applicationId,
          name: session.applicationName,
          duration: session.duration,
        ),
      ),
    );
  }
}
