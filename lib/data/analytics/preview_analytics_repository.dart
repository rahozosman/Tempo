import '../../core/utilities/tempo_dates.dart';
import '../../domain/analytics/analytics_repository.dart';
import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/tracking/usage_session.dart';

/// Sample data for designing and reviewing the interface.
///
/// This is never selected in a release build, and while it is selected the
/// window carries a visible "Preview data" badge. It exists so screens can be
/// judged with realistic shapes; nothing it returns is a measurement.
///
/// Every value is derived from the date itself, so the same day always looks
/// the same and nothing flickers between rebuilds.
class PreviewAnalyticsRepository extends AnalyticsRepository {
  const PreviewAnalyticsRepository();

  static const List<_PreviewApp> _catalogue = <_PreviewApp>[
    _PreviewApp('com.microsoft.VSCode', 'VS Code', 0.30),
    _PreviewApp('com.google.Chrome', 'Chrome', 0.22),
    _PreviewApp('com.apple.Safari', 'Safari', 0.06),
    _PreviewApp('com.spotify.client', 'Spotify', 0.10),
    _PreviewApp('com.hnc.Discord', 'Discord', 0.08),
    _PreviewApp('com.tinyspeck.slackmacgap', 'Slack', 0.07),
    _PreviewApp('com.figma.Desktop', 'Figma', 0.06),
    _PreviewApp('com.apple.Terminal', 'Terminal', 0.05),
    _PreviewApp('com.notion.desktop', 'Notion', 0.04),
    _PreviewApp('explorer.exe', 'File Explorer', 0.02),
  ];

  /// Relative pressure of each hour of the day, before noise.
  static const List<double> _shape = <double>[
    2, 1, 0, 0, 0, 0, 3, 12, 26, 44, 52, 48, //
    30, 38, 50, 54, 47, 40, 26, 34, 38, 30, 18, 8,
  ];

  @override
  Future<DaySummary> day(DateTime date) async => _summary(date, DateTime.now());

  @override
  Future<List<DaySummary>> days(DateTime from, DateTime to) async {
    final DateTime now = DateTime.now();
    final DateTime start = TempoDates.startOfDay(from);
    final DateTime end = TempoDates.startOfDay(to);
    final List<DaySummary> result = <DaySummary>[];
    for (
      DateTime cursor = start;
      !cursor.isAfter(end);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1)
    ) {
      result.add(_summary(cursor, now));
    }
    return result;
  }

  /// Sample sessions for a day, derived from the same shape as its totals, so
  /// the timeline agrees with the bars above it.
  @override
  Future<List<UsageSession>> sessions(DateTime day) async {
    final DateTime now = DateTime.now();
    final DaySummary summary = _summary(day, now);
    if (summary.isEmpty || summary.apps.isEmpty) {
      return const <UsageSession>[];
    }

    final DateTime date = summary.date;
    final _Rng rng = _Rng(_seed(date) ^ 0x77A1);
    final List<AppUsage> apps = summary.apps;
    final int weight = apps.fold<int>(
      0,
      (int total, AppUsage app) => total + app.duration.inSeconds,
    );

    final List<UsageSession> sessions = <UsageSession>[];
    for (int hour = 0; hour < 24; hour++) {
      double remaining = summary.activeMinutesByHour[hour];
      if (remaining < 1) {
        continue;
      }
      DateTime cursor = DateTime(date.year, date.month, date.day, hour);
      while (remaining > 0.6) {
        final double block = remaining < 8
            ? remaining
            : (rng.range(7, 24) > remaining ? remaining : rng.range(7, 24));
        final AppUsage app = _pick(apps, weight, rng);
        final DateTime end = cursor.add(
          Duration(seconds: (block * 60).round()),
        );
        sessions.add(
          UsageSession(
            applicationId: app.id,
            applicationName: app.name,
            start: cursor,
            end: end,
            platform: 'preview',
          ),
        );
        remaining -= block;
        // A small gap between stretches, the way a real day has them.
        cursor = end.add(Duration(seconds: rng.intRange(0, 90)));
        if (cursor.hour != hour) {
          break;
        }
      }
    }
    return sessions;
  }

  /// Picks an application in proportion to how much of the day it took.
  static AppUsage _pick(List<AppUsage> apps, int weight, _Rng rng) {
    if (weight <= 0) {
      return apps.first;
    }
    int target = (rng.nextDouble() * weight).round();
    for (final AppUsage app in apps) {
      target -= app.duration.inSeconds;
      if (target <= 0) {
        return app;
      }
    }
    return apps.last;
  }

  @override
  Future<DateTime?> earliestDay() async {
    final DateTime today = TempoDates.startOfDay(DateTime.now());
    return DateTime(today.year - 2, today.month, today.day);
  }

  DaySummary _summary(DateTime date, DateTime now) {
    final DateTime day = TempoDates.startOfDay(date);
    final DateTime today = TempoDates.startOfDay(now);
    if (day.isAfter(today)) {
      return DaySummary.empty(day);
    }
    // The preview history starts a little over two years back, so year views
    // have a beginning the way real data does.
    if (day.isBefore(DateTime(today.year - 2, today.month, today.day))) {
      return DaySummary.empty(day);
    }

    final List<double> hours = _hours(day, now, today);
    double minutes = 0;
    for (final double value in hours) {
      minutes += value;
    }
    if (minutes < 1) {
      return DaySummary.empty(day);
    }

    final _Rng rng = _Rng(_seed(day) ^ 0x5F3A);
    final Duration active = Duration(seconds: (minutes * 60).round());
    final Duration idle = Duration(
      seconds: (active.inSeconds * rng.range(0.09, 0.22)).round(),
    );
    final int sessions = rng.intRange(11, 12 + (minutes ~/ 12));
    final Duration longest = Duration(
      seconds: (active.inSeconds * rng.range(0.16, 0.34)).round(),
    );

    final Map<String, Duration> previous = _appTimes(
      DateTime(day.year, day.month, day.day - 7),
      now,
      today,
    );
    final Map<String, Duration> current = _split(day, active);

    final List<AppUsage> apps = <AppUsage>[];
    for (final _PreviewApp app in _catalogue) {
      final Duration duration = current[app.id] ?? Duration.zero;
      if (duration.inMinutes < 2) {
        continue;
      }
      apps.add(
        AppUsage(
          id: app.id,
          name: app.name,
          duration: duration,
          previous: previous[app.id],
        ),
      );
    }
    apps.sort((AppUsage a, AppUsage b) => b.duration.compareTo(a.duration));

    return DaySummary(
      date: day,
      active: active,
      idle: idle,
      sessions: sessions,
      longestSession: longest,
      apps: apps,
      activeMinutesByHour: hours,
    );
  }

  /// Active minutes in each hour. Today only fills up to the current moment.
  List<double> _hours(DateTime day, DateTime now, DateTime today) {
    final _Rng rng = _Rng(_seed(day));
    final bool weekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final double energy = rng.range(0.72, 1.12) * (weekend ? 0.62 : 1.0);
    final bool quiet = rng.nextDouble() < 0.07;
    final bool isToday = day.isAtSameMomentAs(today);

    final List<double> hours = List<double>.filled(24, 0);
    for (int hour = 0; hour < 24; hour++) {
      double value = _shape[hour] * energy * rng.range(0.55, 1.35);
      if (quiet) {
        value *= 0.28;
      }
      if (isToday) {
        if (hour > now.hour) {
          value = 0;
        } else if (hour == now.hour) {
          value *= now.minute / 60;
        }
      }
      hours[hour] = value.clamp(0, 60).toDouble();
    }
    return hours;
  }

  Map<String, Duration> _appTimes(
    DateTime day,
    DateTime now,
    DateTime today,
  ) {
    if (day.isAfter(today)) {
      return const <String, Duration>{};
    }
    final List<double> hours = _hours(day, now, today);
    double minutes = 0;
    for (final double value in hours) {
      minutes += value;
    }
    if (minutes < 1) {
      return const <String, Duration>{};
    }
    return _split(day, Duration(seconds: (minutes * 60).round()));
  }

  /// Distributes a day of active time across the catalogue, with each app
  /// keeping its own rhythm from day to day.
  Map<String, Duration> _split(DateTime day, Duration active) {
    final _Rng rng = _Rng(_seed(day) ^ 0x2C91);
    final List<double> weights = <double>[];
    double sum = 0;
    for (final _PreviewApp app in _catalogue) {
      final double weight = app.weight * rng.range(0.45, 1.75);
      weights.add(weight);
      sum += weight;
    }
    final Map<String, Duration> result = <String, Duration>{};
    for (int i = 0; i < _catalogue.length; i++) {
      result[_catalogue[i].id] = Duration(
        seconds: (active.inSeconds * weights[i] / sum).round(),
      );
    }
    return result;
  }

  static int _seed(DateTime day) {
    final int base = day.year * 10000 + day.month * 100 + day.day;
    return (base * 2654435761) & 0x7FFFFFFF;
  }
}

class _PreviewApp {
  const _PreviewApp(this.id, this.name, this.weight);

  final String id;
  final String name;
  final double weight;
}

/// A tiny deterministic generator. Not for anything that needs real entropy.
class _Rng {
  _Rng(this._state);

  int _state;

  int _next() {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state;
  }

  double nextDouble() => _next() / 0x7FFFFFFF;

  double range(double min, double max) => min + nextDouble() * (max - min);

  int intRange(int min, int max) =>
      max <= min ? min : min + _next() % (max - min + 1);
}
