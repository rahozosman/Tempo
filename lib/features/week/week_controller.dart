import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utilities/tempo_dates.dart';
import '../../core/utilities/tempo_format.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../domain/analytics/analytics_repository.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/analytics/usage_aggregate.dart';
import '../../domain/analytics/week_summary.dart';

/// What the seven-day chart is plotting.
enum WeekMeasure {
  screenTime,
  activeTime,
  sessions;

  String get label => switch (this) {
    WeekMeasure.screenTime => 'Screen time',
    WeekMeasure.activeTime => 'Active',
    WeekMeasure.sessions => 'Sessions',
  };

  /// The measure for one day, in whatever unit suits it. The chart only
  /// compares magnitudes, so mixing seconds and counts is safe.
  double amountOf(DaySummary day) => switch (this) {
    WeekMeasure.screenTime => day.total.inSeconds.toDouble(),
    WeekMeasure.activeTime => day.active.inSeconds.toDouble(),
    WeekMeasure.sessions => day.sessions.toDouble(),
  };

  String describe(double amount) => switch (this) {
    WeekMeasure.sessions => TempoFormat.count(amount.round(), 'session'),
    _ => TempoFormat.hm(Duration(seconds: amount.round())),
  };
}

class WeekMeasureController extends Notifier<WeekMeasure> {
  @override
  WeekMeasure build() => WeekMeasure.screenTime;

  void set(WeekMeasure measure) => state = measure;
}

final NotifierProvider<WeekMeasureController, WeekMeasure>
weekMeasureProvider = NotifierProvider<WeekMeasureController, WeekMeasure>(
  WeekMeasureController.new,
);

/// Which week is showing, counted back from this one. 0 is the current week.
class WeekOffsetController extends Notifier<int> {
  @override
  int build() => 0;

  void previous() => state = state - 1;

  void next() {
    if (state < 0) {
      state = state + 1;
    }
  }

  void reset() => state = 0;
}

final NotifierProvider<WeekOffsetController, int> weekOffsetProvider =
    NotifierProvider<WeekOffsetController, int>(WeekOffsetController.new);

/// The Monday of the week currently showing.
DateTime weekStartFor(int offset) {
  final DateTime thisWeek = TempoDates.startOfWeek(DateTime.now());
  return DateTime(
    thisWeek.year,
    thisWeek.month,
    thisWeek.day + offset * 7,
  );
}

final FutureProvider<WeekSummary> weekSummaryProvider =
    FutureProvider<WeekSummary>((Ref ref) async {
      ref.watch(usageRevisionProvider);
      final int offset = ref.watch(weekOffsetProvider);
      final AnalyticsRepository repository = ref.watch(
        analyticsRepositoryProvider,
      );

      final DateTime start = weekStartFor(offset);
      final DateTime end = DateTime(start.year, start.month, start.day + 6);
      final DateTime previousStart = DateTime(
        start.year,
        start.month,
        start.day - 7,
      );
      final DateTime previousEnd = DateTime(
        start.year,
        start.month,
        start.day - 1,
      );

      final List<DaySummary> days = await repository.days(start, end);
      final List<DaySummary> previous = await repository.days(
        previousStart,
        previousEnd,
      );

      return WeekSummary(
        start: start,
        days: days,
        previousDays: previous,
        apps: UsageAggregate.mergeApps(days, previous: previous),
      );
    });
