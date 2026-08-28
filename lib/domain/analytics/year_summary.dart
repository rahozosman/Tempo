import 'package:flutter/foundation.dart';

import 'app_usage.dart';
import 'day_summary.dart';

/// One calendar year, measured in a single pass so the year screen can read
/// any of it without walking the days again.
///
/// The day list is whatever the calendar says: 365 days, or 366 in a leap year.
/// Nothing here assumes a length.
@immutable
class YearSummary {
  const YearSummary._({
    required this.year,
    required this.days,
    required this.apps,
    required this.screenTime,
    required this.activeTime,
    required this.previousScreenTime,
    required this.activeDays,
    required this.previousActiveDays,
    required this.sessions,
    required this.busiest,
    required this.quietest,
    required this.longestSession,
    required this.longestSessionDay,
    required this.monthlyTotals,
    required this.previousMonthlyTotals,
    required this.weekdayTotals,
    required this.weekdayCounts,
  });

  factory YearSummary.build({
    required int year,
    required List<DaySummary> days,
    required List<DaySummary> previousDays,
    required List<AppUsage> apps,
  }) {
    int screenSeconds = 0;
    int activeSeconds = 0;
    int activeDays = 0;
    int sessions = 0;
    DaySummary? busiest;
    DaySummary? quietest;
    Duration longest = Duration.zero;
    DaySummary? longestDay;
    final List<int> monthly = List<int>.filled(12, 0);
    final List<int> weekday = List<int>.filled(7, 0);
    final List<int> weekdayCounts = List<int>.filled(7, 0);

    for (final DaySummary day in days) {
      final int total = day.total.inSeconds;
      screenSeconds += total;
      activeSeconds += day.active.inSeconds;
      sessions += day.sessions;
      monthly[day.date.month - 1] += total;
      if (day.isEmpty) {
        continue;
      }
      activeDays++;
      weekday[day.date.weekday - 1] += total;
      weekdayCounts[day.date.weekday - 1]++;
      if (busiest == null || day.total > busiest.total) {
        busiest = day;
      }
      if (quietest == null || day.total < quietest.total) {
        quietest = day;
      }
      if (day.longestSession > longest) {
        longest = day.longestSession;
        longestDay = day;
      }
    }

    int previousSeconds = 0;
    int previousActive = 0;
    final List<int> previousMonthly = List<int>.filled(12, 0);
    for (final DaySummary day in previousDays) {
      final int total = day.total.inSeconds;
      previousSeconds += total;
      previousMonthly[day.date.month - 1] += total;
      if (!day.isEmpty) {
        previousActive++;
      }
    }

    return YearSummary._(
      year: year,
      days: days,
      apps: apps,
      screenTime: Duration(seconds: screenSeconds),
      activeTime: Duration(seconds: activeSeconds),
      previousScreenTime: Duration(seconds: previousSeconds),
      activeDays: activeDays,
      previousActiveDays: previousActive,
      sessions: sessions,
      busiest: busiest,
      quietest: quietest,
      longestSession: longest,
      longestSessionDay: longestDay,
      monthlyTotals: <Duration>[
        for (final int seconds in monthly) Duration(seconds: seconds),
      ],
      previousMonthlyTotals: <Duration>[
        for (final int seconds in previousMonthly) Duration(seconds: seconds),
      ],
      weekdayTotals: <Duration>[
        for (final int seconds in weekday) Duration(seconds: seconds),
      ],
      weekdayCounts: weekdayCounts,
    );
  }

  final int year;

  /// Every day of the year, 1 January first.
  final List<DaySummary> days;

  /// Applications over the year, ranked, carrying last year for the trend.
  final List<AppUsage> apps;

  final Duration screenTime;
  final Duration activeTime;
  final Duration previousScreenTime;

  final int activeDays;
  final int previousActiveDays;
  final int sessions;

  final DaySummary? busiest;
  final DaySummary? quietest;

  final Duration longestSession;
  final DaySummary? longestSessionDay;

  /// Twelve entries, January first.
  final List<Duration> monthlyTotals;
  final List<Duration> previousMonthlyTotals;

  /// Seven entries, Monday first.
  final List<Duration> weekdayTotals;

  /// How many days of each weekday actually had activity.
  final List<int> weekdayCounts;

  bool get isEmpty => screenTime.inSeconds <= 0;

  /// 366 in a leap year. Read from the day list rather than assumed.
  int get dayCount => days.length;

  bool get isLeapYear => dayCount == 366;

  /// The busiest day sets the top of the heat scale.
  Duration get peak => busiest?.total ?? Duration.zero;

  Duration get dailyAverage => activeDays == 0
      ? Duration.zero
      : Duration(seconds: screenTime.inSeconds ~/ activeDays);

  Duration get previousDailyAverage => previousActiveDays == 0
      ? Duration.zero
      : Duration(seconds: previousScreenTime.inSeconds ~/ previousActiveDays);

  AppUsage? get mostUsed => apps.isEmpty ? null : apps.first;

  double? get totalChange {
    final int before = previousScreenTime.inSeconds;
    if (before <= 0) {
      return null;
    }
    return (screenTime.inSeconds - before) / before;
  }

  double? get averageChange {
    final int before = previousDailyAverage.inSeconds;
    if (before <= 0) {
      return null;
    }
    return (dailyAverage.inSeconds - before) / before;
  }

  /// Index of the heaviest month, or null when the year is empty.
  int? get busiestMonth {
    int? index;
    for (int month = 0; month < monthlyTotals.length; month++) {
      if (monthlyTotals[month].inSeconds <= 0) {
        continue;
      }
      if (index == null || monthlyTotals[month] > monthlyTotals[index]) {
        index = month;
      }
    }
    return index;
  }

  /// Index of the weekday with the highest average, Monday being 0.
  int? get heaviestWeekday {
    int? index;
    Duration best = Duration.zero;
    for (int day = 0; day < weekdayTotals.length; day++) {
      if (weekdayCounts[day] == 0) {
        continue;
      }
      final Duration average = Duration(
        seconds: weekdayTotals[day].inSeconds ~/ weekdayCounts[day],
      );
      if (index == null || average > best) {
        index = day;
        best = average;
      }
    }
    return index;
  }

  Duration weekdayAverage(int weekdayIndex) => weekdayCounts[weekdayIndex] == 0
      ? Duration.zero
      : Duration(
          seconds:
              weekdayTotals[weekdayIndex].inSeconds ~/
              weekdayCounts[weekdayIndex],
        );
}
