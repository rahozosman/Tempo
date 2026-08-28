import 'package:flutter/foundation.dart';

import 'app_usage.dart';
import 'day_summary.dart';

/// One day of one series, used by the per-application history chart.
@immutable
class DayValue {
  const DayValue({required this.date, required this.value});

  final DateTime date;
  final Duration value;
}

/// Pure functions that roll days up into the shapes screens ask for.
///
/// Aggregation lives here rather than in the repository so it behaves the same
/// whatever the days came from, and so a database implementation only has to
/// answer for storage.
class UsageAggregate {
  const UsageAggregate._();

  /// Sum of active time across [days].
  static Duration activeTotal(Iterable<DaySummary> days) {
    int seconds = 0;
    for (final DaySummary day in days) {
      seconds += day.active.inSeconds;
    }
    return Duration(seconds: seconds);
  }

  /// Sum of screen time (active and idle together) across [days].
  static Duration screenTotal(Iterable<DaySummary> days) {
    int seconds = 0;
    for (final DaySummary day in days) {
      seconds += day.total.inSeconds;
    }
    return Duration(seconds: seconds);
  }

  /// Time spent in one application across [days].
  static Duration appTotal(Iterable<DaySummary> days, String id) {
    int seconds = 0;
    for (final DaySummary day in days) {
      for (final AppUsage usage in day.apps) {
        if (usage.id == id) {
          seconds += usage.duration.inSeconds;
        }
      }
    }
    return Duration(seconds: seconds);
  }

  /// The display name last seen for an application, or null if it never
  /// appears in [days].
  static String? nameOf(Iterable<DaySummary> days, String id) {
    String? name;
    for (final DaySummary day in days) {
      for (final AppUsage usage in day.apps) {
        if (usage.id == id) {
          name = usage.name;
        }
      }
    }
    return name;
  }

  /// Merges per-day application time into one ranked list, longest first. When
  /// [previous] is given, each entry carries its total from that earlier span
  /// so trends can be shown.
  static List<AppUsage> mergeApps(
    Iterable<DaySummary> days, {
    Iterable<DaySummary> previous = const <DaySummary>[],
  }) {
    final Map<String, int> seconds = <String, int>{};
    final Map<String, String> names = <String, String>{};
    for (final DaySummary day in days) {
      for (final AppUsage usage in day.apps) {
        seconds[usage.id] = (seconds[usage.id] ?? 0) + usage.duration.inSeconds;
        names[usage.id] = usage.name;
      }
    }

    final Map<String, int> before = <String, int>{};
    for (final DaySummary day in previous) {
      for (final AppUsage usage in day.apps) {
        before[usage.id] = (before[usage.id] ?? 0) + usage.duration.inSeconds;
      }
    }

    final List<AppUsage> merged = <AppUsage>[
      for (final MapEntry<String, int> entry in seconds.entries)
        AppUsage(
          id: entry.key,
          name: names[entry.key] ?? entry.key,
          duration: Duration(seconds: entry.value),
          previous: before.containsKey(entry.key)
              ? Duration(seconds: before[entry.key]!)
              : null,
        ),
    ]..sort((AppUsage a, AppUsage b) => b.duration.compareTo(a.duration));
    return merged;
  }

  /// The daily series for one application, oldest first, including days it was
  /// not used so the chart keeps its rhythm.
  static List<DayValue> seriesFor(Iterable<DaySummary> days, String id) =>
      <DayValue>[
        for (final DaySummary day in days)
          DayValue(date: day.date, value: _durationIn(day, id)),
      ];

  static Duration _durationIn(DaySummary day, String id) {
    for (final AppUsage usage in day.apps) {
      if (usage.id == id) {
        return usage.duration;
      }
    }
    return Duration.zero;
  }

  /// The heaviest entry in a series, or null when the series is all zeros.
  static DayValue? peakOf(Iterable<DayValue> series) {
    DayValue? peak;
    for (final DayValue point in series) {
      if (point.value.inSeconds > 0 &&
          (peak == null || point.value > peak.value)) {
        peak = point;
      }
    }
    return peak;
  }
}
