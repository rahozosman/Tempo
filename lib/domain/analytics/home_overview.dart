import 'package:flutter/foundation.dart';

import 'day_summary.dart';

/// Everything the Home dashboard needs in one value: today, the seven days
/// ending today, and the seven days before those to compare against.
@immutable
class HomeOverview {
  const HomeOverview({
    required this.lastSevenDays,
    required this.previousSevenDays,
  });

  /// Oldest first; the last entry is today.
  final List<DaySummary> lastSevenDays;

  /// The equivalent span immediately before [lastSevenDays].
  final List<DaySummary> previousSevenDays;

  DaySummary get today => lastSevenDays.last;

  Duration get weekTotal => _total(lastSevenDays);

  Duration get previousWeekTotal => _total(previousSevenDays);

  Duration get dailyAverage =>
      Duration(seconds: weekTotal.inSeconds ~/ lastSevenDays.length);

  /// Change against the previous seven days, or null when there is nothing to
  /// compare with yet.
  double? get weekChange {
    final int before = previousWeekTotal.inSeconds;
    if (before <= 0) {
      return null;
    }
    return (weekTotal.inSeconds - before) / before;
  }

  bool get isEmpty => weekTotal.inSeconds <= 0;

  static Duration _total(List<DaySummary> days) {
    int seconds = 0;
    for (final DaySummary day in days) {
      seconds += day.total.inSeconds;
    }
    return Duration(seconds: seconds);
  }
}
