import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/tempo_animations.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/utilities/tempo_format.dart';
import '../../domain/analytics/insight_report.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/awaiting_data.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_segmented.dart';
import '../../shared/widgets/insight_card.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/stats/animated_duration.dart';
import '../../shared/widgets/stats/delta_chip.dart';
import '../../shared/widgets/stats/metric_card.dart';
import '../../shared/widgets/stats/metric_grid.dart';
import '../../shared/widgets/tempo_icon.dart';
import '../sharing/share_sheet.dart';
import 'insight_lines.dart';
import 'insights_controller.dart';

/// Insights: what the stored days actually say, over a week, a month or a
/// year, and the report you can share from them.
class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InsightSpan span = ref.watch(insightSpanProvider);
    final AsyncValue<InsightReport> report = ref.watch(insightReportProvider);
    final InsightReport? loaded = report.value;

    return PageScaffold(
      title: 'Insights',
      subtitle: loaded == null
          ? 'Patterns Tempo notices in your own data'
          : span.describe(loaded.start, loaded.end),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 244,
            child: TempoSegmented<InsightSpan>(
              value: span,
              onChanged: ref.read(insightSpanProvider.notifier).set,
              segments: <TempoSegment<InsightSpan>>[
                for (final InsightSpan value in InsightSpan.values)
                  TempoSegment<InsightSpan>(
                    value: value,
                    label: value.label,
                  ),
              ],
            ),
          ),
          const SizedBox(width: TempoSpace.xs),
          GlassButton(
            label: 'Share report',
            glyph: TempoGlyph.sparkle,
            style: GlassButtonStyle.primary,
            compact: true,
            onPressed: loaded == null || loaded.isEmpty
                ? null
                : () => ShareSheet.open(
                    context,
                    report: loaded,
                    span: span,
                  ),
          ),
        ],
      ),
      child: report.when(
        loading: () => const PageLoading(),
        error: (Object error, StackTrace stack) => ErrorStateView(
          title: 'Unable to read your history',
          message:
              'Tempo could not open its usage database. Restarting the app '
              'usually clears this.',
          detail: error,
        ),
        data: (InsightReport data) => data.isEmpty
            ? const AwaitingData(
                glyph: TempoGlyph.insights,
                title: 'Not enough data yet',
                message:
                    'Insights arrive once there are a few days to compare: '
                    'the longest session, the busiest day, and how this week '
                    'differs from the last.',
              )
            : _InsightsBody(report: data, span: span),
      ),
    );
  }
}

class _InsightsBody extends StatelessWidget {
  const _InsightsBody({required this.report, required this.span});

  final InsightReport report;
  final InsightSpan span;

  @override
  Widget build(BuildContext context) {
    final List<InsightLine> lines = buildInsightLines(report, span);

    return ListView(
      padding: const EdgeInsets.only(bottom: TempoSpace.xl),
      children: <Widget>[
        _HeadlineCard(report: report, span: span),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(
          index: 1,
          child: MetricGrid(
            maxPerRow: 2,
            children: <Widget>[
              for (final InsightLine line in lines)
                InsightCard(
                  glyph: line.glyph,
                  headline: line.headline,
                  detail: line.detail,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.report, required this.span});

  final InsightReport report;
  final InsightSpan span;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;

    return GlassCard(
      hoverLift: false,
      padding: const EdgeInsets.all(TempoSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'YOUR ${span.label.toUpperCase()} SO FAR',
            style: context.typo.labelSmall,
          ),
          const SizedBox(height: TempoSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              AnimatedDuration(
                value: report.screenTime,
                style: context.typo.displayMedium,
              ),
              const SizedBox(width: TempoSpace.md),
              Padding(
                padding: const EdgeInsets.only(bottom: TempoSpace.xs),
                child: DeltaChip(
                  change: report.change,
                  caption: 'vs the ${span.previousLabel}',
                ),
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.sm),
          Text(
            'Screen time ${span.title}, '
            '${TempoFormat.hm(report.activeTime)} of it active and '
            '${TempoFormat.hm(report.idleTime)} idle.',
            style: context.typo.bodyLarge,
          ),
          const SizedBox(height: TempoSpace.lg),
          SplitBar(fraction: 1 - report.idleShare),
          const SizedBox(height: TempoSpace.md),
          Row(
            children: <Widget>[
              _HeadlineStat(
                label: 'Daily average',
                value: TempoFormat.hm(report.dailyAverage),
              ),
              _HeadlineStat(
                label: 'Sessions',
                value: '${report.sessions}',
                tone: c.accentAlt,
              ),
              _HeadlineStat(
                label: 'Longest session',
                value: TempoFormat.hm(report.longestSession),
                tone: c.accentSoft,
              ),
              _HeadlineStat(
                label: 'Days with activity',
                value: '${report.activeDays}',
                tone: c.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeadlineStat extends StatelessWidget {
  const _HeadlineStat({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: tone ?? context.colors.accent,
            ),
          ),
          const SizedBox(width: TempoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label.toUpperCase(),
                  style: context.typo.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(value, style: context.typo.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
