import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utilities/tempo_dates.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../domain/analytics/analytics_repository.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/analytics/month_summary.dart';
import '../../domain/analytics/usage_aggregate.dart';

/// The day opened from the calendar, or null when none is.
class SelectedDayController extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void select(DateTime date) {
    final DateTime day = TempoDates.startOfDay(date);
    state = state != null && state!.isAtSameMomentAs(day) ? null : day;
  }

  void clear() => state = null;
}

final NotifierProvider<SelectedDayController, DateTime?>
selectedDayProvider = NotifierProvider<SelectedDayController, DateTime?>(
  SelectedDayController.new,
);

/// Which month is showing, counted back from this one. 0 is the current month.
class MonthOffsetController extends Notifier<int> {
  @override
  int build() => 0;

  void previous() {
    state = state - 1;
    ref.read(selectedDayProvider.notifier).clear();
  }

  void next() {
    if (state < 0) {
      state = state + 1;
      ref.read(selectedDayProvider.notifier).clear();
    }
  }

  void reset() {
    state = 0;
    ref.read(selectedDayProvider.notifier).clear();
  }
}

final NotifierProvider<MonthOffsetController, int> monthOffsetProvider =
    NotifierProvider<MonthOffsetController, int>(MonthOffsetController.new);

/// The first day of the month currently showing.
DateTime monthStartFor(int offset) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month + offset);
}

final FutureProvider<MonthSummary> monthSummaryProvider =
    FutureProvider<MonthSummary>((Ref ref) async {
      ref.watch(usageRevisionProvider);
      final int offset = ref.watch(monthOffsetProvider);
      final AnalyticsRepository repository = ref.watch(
        analyticsRepositoryProvider,
      );

      final DateTime start = monthStartFor(offset);
      final DateTime end = DateTime(
        start.year,
        start.month,
        TempoDates.daysInMonth(start.year, start.month),
      );
      final DateTime previousStart = DateTime(start.year, start.month - 1);
      final DateTime previousEnd = DateTime(
        previousStart.year,
        previousStart.month,
        TempoDates.daysInMonth(previousStart.year, previousStart.month),
      );

      final List<DaySummary> days = await repository.days(start, end);
      final List<DaySummary> previous = await repository.days(
        previousStart,
        previousEnd,
      );

      return MonthSummary(
        month: start,
        days: days,
        previousDays: previous,
        apps: UsageAggregate.mergeApps(days, previous: previous),
      );
    });
