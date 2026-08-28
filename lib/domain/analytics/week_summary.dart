import 'package:flutter/foundation.dart';

import 'app_usage.dart';
import 'day_summary.dart';
import 'usage_aggregate.dart';

/// One week, with the week before it for contrast.
@immutable
class WeekSummary {
  const WeekSummary({
    required this.start,
    required this.days,
    required this.previousDays,
    required this.apps,
  });

  /// Monday of the week.
  final DateTime start;

  /// Seven days, Monday first.
  final List<DaySummary> days;

  /// The seven days before [start].
  final List<DaySummary> previousDays;

  /// Applications over the week, ranked, carrying last week for the trend.
  final List<AppUsage> apps;

  DateTime get end => DateTime(start.year, start.month, start.day + 6);

  Duration get screenTime => UsageAggregate.screenTotal(days);
  Duration get activeTime => UsageAggregate.activeTotal(days);
  Duration get previousScreenTime => UsageAggregate.screenTotal(previousDays);

  bool get isEmpty => screenTime.inSeconds <= 0;

  int get sessions {
    int total = 0;
    for (final DaySummary day in days) {
      total += day.sessions;
    }
    return total;
  }

  /// Days that actually have something recorded. Averages use this rather than
  /// a flat seven, so a half-finished week is not made to look quiet.
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

  Duration get longestSession {
    Duration longest = Duration.zero;
    for (final DaySummary day in days) {
      if (day.longestSession > longest) {
        longest = day.longestSession;
      }
    }
    return longest;
  }

  DaySummary? get busiestDay {
    DaySummary? busiest;
    for (final DaySummary day in days) {
      if (!day.isEmpty && (busiest == null || day.total > busiest.total)) {
        busiest = day;
      }
    }
    return busiest;
  }

  AppUsage? get mostUsed => apps.isEmpty ? null : apps.first;

  double? get change {
    final int before = previousScreenTime.inSeconds;
    if (before <= 0) {
      return null;
    }
    return (screenTime.inSeconds - before) / before;
  }
}
