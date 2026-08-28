import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/tempo_animations.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/theme/tempo_typography.dart';
import '../../core/utilities/tempo_format.dart';
import '../../domain/analytics/app_usage.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/awaiting_data.dart';
import '../../shared/widgets/glass/glass_segmented.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/stats/animated_duration.dart';
import '../../shared/widgets/stats/metric_card.dart';
import '../../shared/widgets/stats/metric_grid.dart';
import '../../shared/widgets/tempo_icon.dart';
import 'application_detail_view.dart';
import 'applications_controller.dart';
import 'widgets/application_card.dart';

/// Applications. The ranked list, and the history of whichever application is
/// open, sharing one destination in the sidebar.
class ApplicationsPage extends ConsumerWidget {
  const ApplicationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SelectedApp? selected = ref.watch(selectedApplicationProvider);
    final Widget body = TempoPageSwitcher(
      child: selected == null
          ? const _RankedApplications(key: ValueKey<String>('applications'))
          : ApplicationDetailView(
              key: ValueKey<String>(selected.id),
              selection: selected,
            ),
    );

    if (selected == null) {
      return body;
    }
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            ref.read(selectedApplicationProvider.notifier).clear(),
      },
      child: Focus(autofocus: true, child: body),
    );
  }
}

class _RankedApplications extends ConsumerWidget {
  const _RankedApplications({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppsRange range = ref.watch(applicationsRangeProvider);
    final AsyncValue<ApplicationsOverview> overview = ref.watch(
      applicationsOverviewProvider,
    );

    return PageScaffold(
      title: 'Applications',
      subtitle: range.caption,
      trailing: SizedBox(
        width: 264,
        child: TempoSegmented<AppsRange>(
          value: range,
          onChanged: ref.read(applicationsRangeProvider.notifier).set,
          segments: <TempoSegment<AppsRange>>[
            for (final AppsRange value in AppsRange.values)
              TempoSegment<AppsRange>(value: value, label: value.label),
          ],
        ),
      ),
      child: overview.when(
        loading: () => const PageLoading(),
        error: (Object error, StackTrace stack) => ErrorStateView(
          title: 'Unable to read your applications',
          message:
              'Tempo could not open its usage database. Restarting the app '
              'usually clears this.',
          detail: error,
        ),
        data: (ApplicationsOverview data) => data.isEmpty
            ? const AwaitingData(
                glyph: TempoGlyph.apps,
                title: 'No applications recorded yet',
                message:
                    'Each application gets a card with its time, its share of '
                    'the period and how it is trending. Open one for its full '
                    'history.',
              )
            : _RankedList(overview: data),
      ),
    );
  }
}

class _RankedList extends ConsumerWidget {
  const _RankedList({required this.overview});

  final ApplicationsOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AppUsage> apps = overview.apps;
    final AppUsage leader = apps.first;
    final double? change = overview.change;

    return ListView(
      padding: const EdgeInsets.only(bottom: TempoSpace.xl),
      children: <Widget>[
        MetricGrid(
          children: <Widget>[
            MetricCard(
              label: 'Active time',
              glyph: TempoGlyph.clock,
              value: AnimatedDuration(
                value: overview.total,
                style: context.typo.headlineLarge,
              ),
              caption: 'Across every application',
            ),
            MetricCard(
              label: 'Applications',
              glyph: TempoGlyph.apps,
              tone: context.colors.accentAlt,
              value: AnimatedCount(
                value: apps.length,
                style: context.typo.headlineLarge,
              ),
              caption: 'Averaging ${TempoFormat.hm(overview.averagePerApp)} '
                  'each',
            ),
            MetricCard(
              label: 'Most used',
              glyph: TempoGlyph.insights,
              tone: context.colors.accentSoft,
              value: Text(
                leader.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typo.headlineMedium,
              ),
              caption:
                  '${TempoFormat.hm(leader.duration)} · '
                  '${TempoFormat.percent(leader.shareOf(overview.total))} of '
                  'the period',
              onTap: () => openApplication(ref, leader),
            ),
            MetricCard(
              label: 'Compared',
              glyph: change == null || change >= 0
                  ? TempoGlyph.trendUp
                  : TempoGlyph.trendDown,
              value: Text(
                change == null ? '—' : TempoFormat.signedPercent(change),
                style: context.typo.headlineLarge?.copyWith(
                  fontFeatures: TempoTypography.numeric,
                ),
              ),
              caption: change == null
                  ? 'Nothing to compare with yet'
                  : '${TempoFormat.hm(overview.previousTotal)} ${overview.range.comparison}',
            ),
          ],
        ),
        const SizedBox(height: TempoSpace.lg),
        for (int i = 0; i < apps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: TempoSpace.sm),
            child: ApplicationCard(
              rank: i + 1,
              usage: apps[i],
              total: overview.total,
              index: i,
              onTap: () => openApplication(ref, apps[i]),
            ),
          ),
      ],
    );
  }
}
