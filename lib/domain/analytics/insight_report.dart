import 'package:flutter/foundation.dart';

import 'app_usage.dart';
import 'day_summary.dart';

/// A span of days reduced to the handful of facts the Insights screen and the
/// shared report are built from.
@immutable
class InsightReport {
  const InsightReport._({
    required this.start,
    required this.end,
    required this.days,
    required this.apps,
    required this.screenTime,
    required this.activeTime,
    required this.idleTime,
    required this.previousScreenTime,
    required this.activeDays,
    required this.sessions,
    required this.busiest,
    required this.quietest,
    required this.longestSession,
    required this.longestSessionDay,
  });

  factory InsightReport.build({
    required DateTime start,
    required DateTime end,
    required List<DaySummary> days,
    required List<DaySummary> previousDays,
    required List<AppUsage> apps,
  }) {
    int screen = 0;
    int active = 0;
    int idle = 0;
    int sessions = 0;
    int activeDays = 0;
    DaySummary? busiest;
    DaySummary? quietest;
    Duration longest = Duration.zero;
    DaySummary? longestDay;

    for (final DaySummary day in days) {
      screen += day.total.inSeconds;
      active += day.active.inSeconds;
      idle += day.idle.inSeconds;
      sessions += day.sessions;
      if (day.isEmpty) {
        continue;
      }
      activeDays++;
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

    int previous = 0;
    for (final DaySummary day in previousDays) {
      previous += day.total.inSeconds;
    }

    return InsightReport._(
      start: start,
      end: end,
      days: days,
      apps: apps,
      screenTime: Duration(seconds: screen),
      activeTime: Duration(seconds: active),
      idleTime: Duration(seconds: idle),
      previousScreenTime: Duration(seconds: previous),
      activeDays: activeDays,
      sessions: sessions,
      busiest: busiest,
      quietest: quietest,
      longestSession: longest,
      longestSessionDay: longestDay,
    );
  }

  final DateTime start;
  final DateTime end;
  final List<DaySummary> days;

  /// Ranked, carrying the equivalent span before this one.
  final List<AppUsage> apps;

  final Duration screenTime;
  final Duration activeTime;
  final Duration idleTime;
  final Duration previousScreenTime;

  final int activeDays;
  final int sessions;

  final DaySummary? busiest;
  final DaySummary? quietest;
  final Duration longestSession;
  final DaySummary? longestSessionDay;

  bool get isEmpty => screenTime.inSeconds <= 0;

  Duration get dailyAverage => activeDays == 0
      ? Duration.zero
      : Duration(seconds: screenTime.inSeconds ~/ activeDays);

  Duration get averageSession => sessions == 0
      ? Duration.zero
      : Duration(seconds: activeTime.inSeconds ~/ sessions);

  double get idleShare => screenTime.inSeconds <= 0
      ? 0
      : idleTime.inSeconds / screenTime.inSeconds;

  AppUsage? get mostUsed => apps.isEmpty ? null : apps.first;

  AppUsage? get runnerUp => apps.length < 2 ? null : apps[1];

  double? get change {
    final int before = previousScreenTime.inSeconds;
    if (before <= 0) {
      return null;
    }
    return (screenTime.inSeconds - before) / before;
  }
}
