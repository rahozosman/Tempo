import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utilities/tempo_dates.dart';
import '../../core/utilities/tempo_format.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../domain/analytics/analytics_repository.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/analytics/insight_report.dart';
import '../../domain/analytics/usage_aggregate.dart';

/// The span Insights and the shared report are measured over.
enum InsightSpan {
  week,
  month,
  year;

  String get label => switch (this) {
    InsightSpan.week => 'Week',
    InsightSpan.month => 'Month',
    InsightSpan.year => 'Year',
  };

  String get title => switch (this) {
    InsightSpan.week => 'this week',
    InsightSpan.month => 'this month',
    InsightSpan.year => 'this year',
  };

  String get previousLabel => switch (this) {
    InsightSpan.week => 'week before',
    InsightSpan.month => 'month before',
    InsightSpan.year => 'year before',
  };

  String get shareHeading => switch (this) {
    InsightSpan.week => 'MY WEEK',
    InsightSpan.month => 'MY MONTH',
    InsightSpan.year => 'MY YEAR',
  };

  /// The first day of the span containing [today].
  DateTime startFor(DateTime today) => switch (this) {
    InsightSpan.week => TempoDates.startOfWeek(today),
    InsightSpan.month => DateTime(today.year, today.month),
    InsightSpan.year => DateTime(today.year),
  };

  /// The first day of the span before the one starting at [start].
  DateTime previousStartFor(DateTime start) => switch (this) {
    InsightSpan.week => DateTime(start.year, start.month, start.day - 7),
    InsightSpan.month => DateTime(start.year, start.month - 1),
    InsightSpan.year => DateTime(start.year - 1),
  };

  /// "18 – 24 August", "August so far", "2026 so far".
  String describe(DateTime start, DateTime today) => switch (this) {
    InsightSpan.week =>
      '${TempoFormat.monthDay(start)} – ${TempoFormat.monthDay(today)}',
    InsightSpan.month => '${TempoDates.monthAndYear(start)} so far',
    InsightSpan.year => '${start.year} so far',
  };
}

class InsightSpanController extends Notifier<InsightSpan> {
  @override
  InsightSpan build() => InsightSpan.week;

  void set(InsightSpan span) => state = span;
}

final NotifierProvider<InsightSpanController, InsightSpan> insightSpanProvider =
    NotifierProvider<InsightSpanController, InsightSpan>(
      InsightSpanController.new,
    );

/// The span so far, against exactly as many days of the span before it, so a
/// half-finished week is never compared with a whole one.
final FutureProvider<InsightReport> insightReportProvider =
    FutureProvider<InsightReport>((Ref ref) async {
      ref.watch(usageRevisionProvider);
      final InsightSpan span = ref.watch(insightSpanProvider);
      final AnalyticsRepository repository = ref.watch(
        analyticsRepositoryProvider,
      );

      final DateTime today = TempoDates.startOfDay(DateTime.now());
      final DateTime start = span.startFor(today);
      final int elapsed = TempoDates.daysBetween(start, today) + 1;
      final DateTime previousStart = span.previousStartFor(start);
      final DateTime previousEnd = DateTime(
        previousStart.year,
        previousStart.month,
        previousStart.day + elapsed - 1,
      );

      final List<DaySummary> days = await repository.days(start, today);
      final List<DaySummary> previous = await repository.days(
        previousStart,
        previousEnd,
      );

      return InsightReport.build(
        start: start,
        end: today,
        days: days,
        previousDays: previous,
        apps: UsageAggregate.mergeApps(days, previous: previous),
      );
    });
