import 'package:flutter/foundation.dart';

import 'app_usage.dart';

/// One day of measured activity.
///
/// [active] is time the computer was actually being used; [idle] is time it was
/// awake but untouched. Screen time is the two together. Application time only
/// ever adds up to [active] — idle stretches belong to no application.
@immutable
class DaySummary {
  const DaySummary({
    required this.date,
    required this.active,
    required this.idle,
    required this.sessions,
    required this.longestSession,
    required this.apps,
    required this.activeMinutesByHour,
  });

  factory DaySummary.empty(DateTime date) => DaySummary(
    date: DateTime(date.year, date.month, date.day),
    active: Duration.zero,
    idle: Duration.zero,
    sessions: 0,
    longestSession: Duration.zero,
    apps: const <AppUsage>[],
    activeMinutesByHour: zeroHours,
  );

  /// Midnight, local time.
  final DateTime date;

  final Duration active;
  final Duration idle;

  /// Number of distinct application sessions recorded.
  final int sessions;

  final Duration longestSession;

  /// Sorted longest first.
  final List<AppUsage> apps;

  /// 24 entries, active minutes in each hour of the local day.
  final List<double> activeMinutesByHour;

  static const List<double> zeroHours = <double>[
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ];

  Duration get total => active + idle;

  bool get isEmpty => total.inSeconds <= 0;

  double get activeShare =>
      total.inSeconds <= 0 ? 0 : active.inSeconds / total.inSeconds;

  Duration get averageSession =>
      sessions <= 0 ? Duration.zero : Duration(seconds: active.inSeconds ~/ sessions);

  AppUsage? get topApp => apps.isEmpty ? null : apps.first;

  /// The [limit] longest applications, with everything else folded into a
  /// single trailing entry so the list still adds up to the whole day.
  List<AppUsage> topApps(int limit, {String otherLabel = 'Other'}) {
    if (apps.length <= limit) {
      return apps;
    }
    final List<AppUsage> head = apps.sublist(0, limit);
    Duration rest = Duration.zero;
    for (final AppUsage usage in apps.sublist(limit)) {
      rest += usage.duration;
    }
    return <AppUsage>[
      ...head,
      AppUsage(id: '__other__', name: otherLabel, duration: rest),
    ];
  }
}
