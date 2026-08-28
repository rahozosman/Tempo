import 'package:flutter/foundation.dart';

import 'app_usage.dart';
import 'day_summary.dart';
import 'usage_aggregate.dart';

/// One calendar month, with the month before it for contrast.
@immutable
class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.days,
    required this.previousDays,
    required this.apps,
  });

  /// The first of the month.
  final DateTime month;

  /// Every day of the month, first to last.
  final List<DaySummary> days;

  final List<DaySummary> previousDays;

  /// Applications over the month, ranked, carrying last month for the trend.
  final List<AppUsage> apps;

  Duration get screenTime => UsageAggregate.screenTotal(days);
  Duration get activeTime => UsageAggregate.activeTotal(days);
  Duration get previousScreenTime => UsageAggregate.screenTotal(previousDays);

  bool get isEmpty => screenTime.inSeconds <= 0;

  int get recordedDays {
    int count = 0;
    for (final DaySummary day in days) {
      if (!day.isEmpty) {
        count++;
      }
    }
    return count;
  }

  Duration get dailyAverage => recordedDays == 0
      ? Duration.zero
      : Duration(seconds: screenTime.inSeconds ~/ recordedDays);

  /// The busiest day, which also sets the top of the heat scale.
  DaySummary? get busiest {
    DaySummary? peak;
    for (final DaySummary day in days) {
      if (!day.isEmpty && (peak == null || day.total > peak.total)) {
        peak = day;
      }
    }
    return peak;
  }

  /// The lightest day that still had something recorded.
  DaySummary? get quietest {
    DaySummary? low;
    for (final DaySummary day in days) {
      if (!day.isEmpty && (low == null || day.total < low.total)) {
        low = day;
      }
    }
    return low;
  }

  Duration get peak => busiest?.total ?? Duration.zero;

  AppUsage? get mostUsed => apps.isEmpty ? null : apps.first;

  double? get change {
    final int before = previousScreenTime.inSeconds;
    if (before <= 0) {
      return null;
    }
    return (screenTime.inSeconds - before) / before;
  }

  /// Screen time per weekday across the month, Monday first, and how many
  /// days of each weekday actually had activity.
  ({List<Duration> totals, List<int> counts}) get byWeekday {
    final List<int> totals = List<int>.filled(7, 0);
    final List<int> counts = List<int>.filled(7, 0);
    for (final DaySummary day in days) {
      if (day.isEmpty) {
        continue;
      }
      totals[day.date.weekday - 1] += day.total.inSeconds;
      counts[day.date.weekday - 1]++;
    }
    return (
      totals: <Duration>[
        for (final int seconds in totals) Duration(seconds: seconds),
      ],
      counts: counts,
    );
  }

  Duration weekdayAverage(int weekdayIndex) {
    final ({List<Duration> totals, List<int> counts}) week = byWeekday;
    final int count = week.counts[weekdayIndex];
    return count == 0
        ? Duration.zero
        : Duration(seconds: week.totals[weekdayIndex].inSeconds ~/ count);
  }

  /// The weekday with the highest average, Monday being 0.
  int? get heaviestWeekday {
    final ({List<Duration> totals, List<int> counts}) week = byWeekday;
    int? index;
    Duration best = Duration.zero;
    for (int day = 0; day < 7; day++) {
      if (week.counts[day] == 0) {
        continue;
      }
      final Duration average = Duration(
        seconds: week.totals[day].inSeconds ~/ week.counts[day],
      );
      if (index == null || average > best) {
        index = day;
        best = average;
      }
    }
    return index;
  }

  /// The day matching [date], or null when it falls outside the month.
  DaySummary? dayOn(DateTime date) {
    for (final DaySummary day in days) {
      if (day.date.year == date.year &&
          day.date.month == date.month &&
          day.date.day == date.day) {
        return day;
      }
    }
    return null;
  }
}
