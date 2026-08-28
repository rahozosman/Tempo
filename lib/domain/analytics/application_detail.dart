import 'package:flutter/foundation.dart';

import 'usage_aggregate.dart';

/// Everything the application detail screen shows about one application.
@immutable
class ApplicationDetail {
  const ApplicationDetail({
    required this.id,
    required this.name,
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.thisYear,
    required this.previousWeek,
    required this.series,
    required this.activeDays,
    required this.screenTimeThisYear,
    required this.busiest,
  });

  final String id;
  final String name;

  final Duration today;

  /// Monday to now.
  final Duration thisWeek;

  /// The calendar month so far.
  final Duration thisMonth;

  /// The calendar year so far.
  final Duration thisYear;

  /// The seven days before this week, for the trend.
  final Duration previousWeek;

  /// The last thirty days, oldest first.
  final List<DayValue> series;

  /// Days this year the application was used at all.
  final int activeDays;

  /// All active time this year, whatever the application.
  final Duration screenTimeThisYear;

  /// The heaviest day on record this year, or null if there is none.
  final DayValue? busiest;

  bool get isEmpty => thisYear.inSeconds <= 0;

  double? get weekChange {
    final int before = previousWeek.inSeconds;
    if (before <= 0) {
      return null;
    }
    return (thisWeek.inSeconds - before) / before;
  }

  /// Share of all the active time measured this year.
  double get shareOfYear => screenTimeThisYear.inSeconds <= 0
      ? 0
      : thisYear.inSeconds / screenTimeThisYear.inSeconds;

  Duration get averagePerActiveDay => activeDays <= 0
      ? Duration.zero
      : Duration(seconds: thisYear.inSeconds ~/ activeDays);
}
