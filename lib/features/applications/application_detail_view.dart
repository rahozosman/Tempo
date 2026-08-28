import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/tempo_animations.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/utilities/tempo_format.dart';
import '../../domain/analytics/application_detail.dart';
import '../../shared/widgets/app_glyph.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/stats/animated_duration.dart';
import '../../shared/widgets/stats/delta_chip.dart';
import '../../shared/widgets/stats/metric_card.dart';
import '../../shared/widgets/stats/metric_grid.dart';
import '../../shared/widgets/tempo_icon.dart';
import 'applications_controller.dart';
import 'widgets/category_card.dart';
import 'widgets/limits_card.dart';
import 'widgets/application_history_card.dart';

/// One application in full: its totals, its history, and what Tempo can say
/// about it from the days it has stored.
class ApplicationDetailView extends ConsumerWidget {
  const ApplicationDetailView({super.key, required this.selection});

  final SelectedApp selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ApplicationDetail?> detail = ref.watch(
      applicationDetailProvider(selection.id),
    );
    final ApplicationDetail? loaded = detail.value;

    void back() => ref.read(selectedApplicationProvider.notifier).clear();

    return PageScaffold(
      leading: Hero(
        tag: 'application-${selection.id}',
        child: AppGlyph(id: selection.id, name: selection.name, size: 48),
      ),
      title: selection.name,
      subtitle: selection.id,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (loaded != null && !loaded.isEmpty) ...<Widget>[
            DeltaChip(
              change: loaded.weekChange,
              caption: 'vs last week',
              compact: true,
            ),
            const SizedBox(width: TempoSpace.sm),
          ],
          GlassButton(
            label: 'All applications',
            glyph: TempoGlyph.chevronLeft,
            compact: true,
            onPressed: back,
          ),
        ],
      ),
      child: detail.when(
        loading: () => const PageLoading(),
        error: (Object error, StackTrace stack) => ErrorStateView(
          title: 'Unable to read this application',
          message:
              'Tempo could not read the stored history for ${selection.name}. '
              'Restarting the app usually clears this.',
          detail: error,
        ),
        data: (ApplicationDetail? data) => data == null || data.isEmpty
            ? EmptyState(
                glyph: TempoGlyph.apps,
                title: 'No history yet',
                message:
                    'Tempo has not recorded any time in ${selection.name} '
                    'this year.',
                action: GlassButton(
                  label: 'Back to applications',
                  glyph: TempoGlyph.chevronLeft,
                  onPressed: back,
                ),
              )
            : _DetailBody(detail: data),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final ApplicationDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: TempoSpace.xl),
      children: <Widget>[
        MetricGrid(
          children: <Widget>[
            MetricCard(
              label: 'Today',
              glyph: TempoGlyph.today,
              value: AnimatedDuration(
                value: detail.today,
                style: context.typo.headlineLarge,
              ),
            ),
            MetricCard(
              label: 'This week',
              glyph: TempoGlyph.week,
              tone: context.colors.accentAlt,
              value: AnimatedDuration(
                value: detail.thisWeek,
                style: context.typo.headlineLarge,
              ),
            ),
            MetricCard(
              label: 'This month',
              glyph: TempoGlyph.month,
              tone: context.colors.accentSoft,
              value: AnimatedDuration(
                value: detail.thisMonth,
                style: context.typo.headlineLarge,
              ),
            ),
            MetricCard(
              label: 'This year',
              glyph: TempoGlyph.year,
              value: AnimatedDuration(
                value: detail.thisYear,
                style: context.typo.headlineLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(
          index: 1,
          child: ApplicationHistoryCard(series: detail.series),
        ),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(
          index: 2,
          child: GlassCard(
            hoverLift: false,
            padding: const EdgeInsets.symmetric(
              horizontal: TempoSpace.xl,
              vertical: TempoSpace.xs,
            ),
            child: Column(
              children: <Widget>[
                _FactRow(
                  label: 'Daily limit',
                  value: '',
                  trailing: LimitPicker(applicationId: detail.id),
                ),
                const _FactDivider(),
                _FactRow(
                  label: 'Category',
                  value: '',
                  trailing: CategoryPicker(applicationId: detail.id),
                ),
                const _FactDivider(),
                _FactRow(
                  label: 'Busiest day',
                  value: detail.busiest == null
                      ? 'Nothing recorded yet'
                      : TempoFormat.dayLong(detail.busiest!.date),
                  caption: detail.busiest == null
                      ? null
                      : TempoFormat.hm(detail.busiest!.value),
                ),
                const _FactDivider(),
                _FactRow(
                  label: 'Days used this year',
                  value: TempoFormat.count(detail.activeDays, 'day'),
                ),
                const _FactDivider(),
                _FactRow(
                  label: 'Share of your active time',
                  value: TempoFormat.percent(detail.shareOfYear),
                  caption: 'of everything measured this year',
                ),
                const _FactDivider(),
                _FactRow(
                  label: 'Average on a day it is used',
                  value: TempoFormat.hm(detail.averagePerActiveDay),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.label,
    required this.value,
    this.caption,
    this.trailing,
  });

  final String label;
  final String value;
  final String? caption;

  /// Replaces the value when the fact is something you can change.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TempoSpace.md),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: context.typo.bodyLarge)),
          const SizedBox(width: TempoSpace.lg),
          if (trailing != null)
            Flexible(child: trailing!)
          else
            Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(value, style: context.typo.titleSmall),
              if (caption != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(caption!, style: context.typo.bodySmall),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FactDivider extends StatelessWidget {
  const _FactDivider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: context.colors.border);
}
