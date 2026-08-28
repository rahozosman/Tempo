import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utilities/tempo_dates.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../domain/analytics/analytics_repository.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/analytics/usage_aggregate.dart';
import '../../domain/analytics/year_summary.dart';

/// The day opened from the activity grid.
class YearDayController extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void select(DateTime date) {
    final DateTime day = TempoDates.startOfDay(date);
    state = state != null && state!.isAtSameMomentAs(day) ? null : day;
  }

  void clear() => state = null;
}

final NotifierProvider<YearDayController, DateTime?> yearDayProvider =
    NotifierProvider<YearDayController, DateTime?>(YearDayController.new);

/// The year on screen. Always taken from the calendar, never hard-coded.
class SelectedYearController extends Notifier<int> {
  @override
  int build() => DateTime.now().year;

  void set(int year) {
    state = year;
    ref.read(yearDayProvider.notifier).clear();
  }

  void previous() => set(state - 1);

  void next() => set(state + 1);

  void reset() => set(DateTime.now().year);
}

final NotifierProvider<SelectedYearController, int> selectedYearProvider =
    NotifierProvider<SelectedYearController, int>(SelectedYearController.new);

/// Every year Tempo can show, oldest first: from the first recorded day to
/// this one. With nothing recorded, only the current year is offered.
final FutureProvider<List<int>> availableYearsProvider =
    FutureProvider<List<int>>((Ref ref) async {
      ref.watch(usageRevisionProvider);
      final AnalyticsRepository repository = ref.watch(
        analyticsRepositoryProvider,
      );
      final int current = DateTime.now().year;
      final DateTime? earliest = await repository.earliestDay();
      if (earliest == null || earliest.year >= current) {
        return <int>[current];
      }
      return <int>[
        for (int year = earliest.year; year <= current; year++) year,
      ];
    });

final FutureProvider<YearSummary> yearSummaryProvider =
    FutureProvider<YearSummary>((Ref ref) async {
      ref.watch(usageRevisionProvider);
      final int year = ref.watch(selectedYearProvider);
      final AnalyticsRepository repository = ref.watch(
        analyticsRepositoryProvider,
      );

      // 31 December resolves correctly in leap and common years alike, so the
      // day list is 365 or 366 entries without anything assuming a length.
      final List<DaySummary> days = await repository.days(
        DateTime(year),
        DateTime(year, 12, 31),
      );
      final List<DaySummary> previous = await repository.days(
        DateTime(year - 1),
        DateTime(year - 1, 12, 31),
      );

      return YearSummary.build(
        year: year,
        days: days,
        previousDays: previous,
        apps: UsageAggregate.mergeApps(days, previous: previous),
      );
    });
