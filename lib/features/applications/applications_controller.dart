import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utilities/tempo_dates.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../domain/analytics/analytics_repository.dart';
import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/application_detail.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/analytics/usage_aggregate.dart';
import '../navigation/nav_destination.dart';
import '../navigation/navigation_controller.dart';

/// The span the Applications screen ranks by.
enum AppsRange {
  today,
  week,
  month;

  String get label => switch (this) {
    AppsRange.today => 'Today',
    AppsRange.week => '7 days',
    AppsRange.month => '30 days',
  };

  String get caption => switch (this) {
    AppsRange.today => 'Ranked by time today',
    AppsRange.week => 'Ranked by time over the last seven days',
    AppsRange.month => 'Ranked by time over the last thirty days',
  };

  String get comparison => switch (this) {
    AppsRange.today => 'vs yesterday',
    AppsRange.week => 'vs the seven before',
    AppsRange.month => 'vs the thirty before',
  };

  int get days => switch (this) {
    AppsRange.today => 1,
    AppsRange.week => 7,
    AppsRange.month => 30,
  };
}

/// Applications ranked over one span, with the same span before it to compare.
@immutable
class ApplicationsOverview {
  const ApplicationsOverview({
    required this.range,
    required this.apps,
    required this.total,
    required this.previousTotal,
  });

  final AppsRange range;

  /// Longest first.
  final List<AppUsage> apps;

  /// Active time in the span, whatever the application.
  final Duration total;

  final Duration previousTotal;

  bool get isEmpty => apps.isEmpty;

  double? get change {
    final int before = previousTotal.inSeconds;
    if (before <= 0) {
      return null;
    }
    return (total.inSeconds - before) / before;
  }

  Duration get averagePerApp => apps.isEmpty
      ? Duration.zero
      : Duration(seconds: total.inSeconds ~/ apps.length);
}

class ApplicationsRangeController extends Notifier<AppsRange> {
  @override
  AppsRange build() => AppsRange.week;

  void set(AppsRange range) => state = range;
}

final NotifierProvider<ApplicationsRangeController, AppsRange>
applicationsRangeProvider =
    NotifierProvider<ApplicationsRangeController, AppsRange>(
      ApplicationsRangeController.new,
    );

final FutureProvider<ApplicationsOverview> applicationsOverviewProvider =
    FutureProvider<ApplicationsOverview>((Ref ref) async {
      ref.watch(usageRevisionProvider);
      final AppsRange range = ref.watch(applicationsRangeProvider);
      final AnalyticsRepository repository = ref.watch(
        analyticsRepositoryProvider,
      );
      final DateTime today = TempoDates.startOfDay(DateTime.now());
      final int span = range.days;

      final List<DaySummary> current = await repository.days(
        DateTime(today.year, today.month, today.day - (span - 1)),
        today,
      );
      final List<DaySummary> previous = await repository.days(
        DateTime(today.year, today.month, today.day - (span * 2 - 1)),
        DateTime(today.year, today.month, today.day - span),
      );

      return ApplicationsOverview(
        range: range,
        apps: UsageAggregate.mergeApps(current, previous: previous),
        total: UsageAggregate.activeTotal(current),
        previousTotal: UsageAggregate.activeTotal(previous),
      );
    });

/// The application whose history is open. The name travels with the identity
/// so the detail header can be drawn before its history has loaded.
@immutable
class SelectedApp {
  const SelectedApp({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is SelectedApp && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// The open application, or null for the ranked list.
class SelectedApplicationController extends Notifier<SelectedApp?> {
  @override
  SelectedApp? build() => null;

  void open(SelectedApp app) => state = app;

  void clear() => state = null;
}

final NotifierProvider<SelectedApplicationController, SelectedApp?>
selectedApplicationProvider =
    NotifierProvider<SelectedApplicationController, SelectedApp?>(
      SelectedApplicationController.new,
    );

/// The full history of one application. Null when the application has no
/// recorded time this year, which is how a stale selection resolves.
final applicationDetailProvider =
    FutureProvider.family<ApplicationDetail?, String>((
      Ref ref,
      String id,
    ) async {
      ref.watch(usageRevisionProvider);
      final AnalyticsRepository repository = ref.watch(
        analyticsRepositoryProvider,
      );
      final DateTime today = TempoDates.startOfDay(DateTime.now());
      final DateTime yearStart = DateTime(today.year);
      final DateTime windowStart = DateTime(
        today.year,
        today.month,
        today.day - 29,
      );
      final DateTime start = windowStart.isBefore(yearStart)
          ? windowStart
          : yearStart;

      final List<DaySummary> days = await repository.days(start, today);
      final String? name = UsageAggregate.nameOf(days, id);
      if (name == null) {
        return null;
      }

      final DateTime weekStart = TempoDates.startOfWeek(today);
      final DateTime previousWeekStart = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day - 7,
      );
      final DateTime monthStart = DateTime(today.year, today.month);

      final List<DaySummary> yearDays = <DaySummary>[
        for (final DaySummary day in days)
          if (!day.date.isBefore(yearStart)) day,
      ];
      final List<DaySummary> window = <DaySummary>[
        for (final DaySummary day in days)
          if (!day.date.isBefore(windowStart)) day,
      ];
      final List<DaySummary> weekDays = <DaySummary>[
        for (final DaySummary day in days)
          if (!day.date.isBefore(weekStart)) day,
      ];
      final List<DaySummary> previousWeekDays = <DaySummary>[
        for (final DaySummary day in days)
          if (!day.date.isBefore(previousWeekStart) &&
              day.date.isBefore(weekStart))
            day,
      ];
      final List<DaySummary> monthDays = <DaySummary>[
        for (final DaySummary day in days)
          if (!day.date.isBefore(monthStart)) day,
      ];

      final List<DayValue> yearSeries = UsageAggregate.seriesFor(yearDays, id);
      int activeDays = 0;
      for (final DayValue point in yearSeries) {
        if (point.value.inSeconds > 0) {
          activeDays++;
        }
      }

      return ApplicationDetail(
        id: id,
        name: name,
        today: UsageAggregate.appTotal(
          <DaySummary>[if (days.isNotEmpty) days.last],
          id,
        ),
        thisWeek: UsageAggregate.appTotal(weekDays, id),
        thisMonth: UsageAggregate.appTotal(monthDays, id),
        thisYear: UsageAggregate.appTotal(yearDays, id),
        previousWeek: UsageAggregate.appTotal(previousWeekDays, id),
        series: UsageAggregate.seriesFor(window, id),
        activeDays: activeDays,
        screenTimeThisYear: UsageAggregate.activeTotal(yearDays),
        busiest: UsageAggregate.peakOf(yearSeries),
      );
    });

/// Opens an application from anywhere in the app: selects it and moves the
/// sidebar to Applications. Grouped entries such as "Other" have no history of
/// their own, so they only open the ranked list.
void openApplication(WidgetRef ref, AppUsage usage) {
  if (usage.id.startsWith('__')) {
    ref.read(selectedApplicationProvider.notifier).clear();
  } else {
    ref
        .read(selectedApplicationProvider.notifier)
        .open(SelectedApp(id: usage.id, name: usage.name));
  }
  ref.read(navigationProvider.notifier).selectSection(TempoSection.applications);
}
