import 'dart:convert';

import 'package:intl/intl.dart';

import '../../core/constants/app_info.dart';
import '../../core/utilities/tempo_dates.dart';
import '../../domain/analytics/analytics_repository.dart';
import '../../domain/analytics/app_usage.dart';
import '../../data/database/usage_dao.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/tracking/usage_session.dart';
import '../sharing/share_service.dart';

enum ExportFormat {
  csv,
  json;

  String get extension => switch (this) {
    ExportFormat.csv => 'csv',
    ExportFormat.json => 'json',
  };

  String get label => switch (this) {
    ExportFormat.csv => 'CSV',
    ExportFormat.json => 'JSON',
  };
}

/// What an export produced: where it landed, and how many days it covered.
class ExportResult {
  const ExportResult({required this.path, required this.days});

  final String? path;
  final int days;

  bool get isEmpty => days == 0;
}

/// Writes the stored history to a file the person can keep.
///
/// Everything Tempo holds today is a daily roll-up, so that is exactly what is
/// written: one row per application per day, with the day's totals alongside.
/// Session start and end times join the export when the tracking engine begins
/// recording them.
class ExportService {
  const ExportService._();

  static final DateFormat _date = DateFormat('yyyy-MM-dd');

  static Future<ExportResult> export({
    required AnalyticsRepository repository,
    required ExportFormat format,
    required bool isPreview,
    UsageDao? usage,
  }) async {
    final DateTime today = TempoDates.startOfDay(DateTime.now());
    final DateTime? earliest = await repository.earliestDay();
    final DateTime start = earliest ?? DateTime(today.year);
    final List<DaySummary> days = await repository.days(start, today);
    int recorded = 0;
    for (final DaySummary day in days) {
      if (!day.isEmpty) {
        recorded++;
      }
    }
    if (recorded == 0) {
      return const ExportResult(path: null, days: 0);
    }

    // JSON carries the sessions as well as the roll-ups, which is what makes
    // it a backup rather than a summary.
    final Map<String, List<UsageSession>> sessions =
        format == ExportFormat.json && usage != null
        ? _byDay(await usage.sessionsBetween(start, today))
        : const <String, List<UsageSession>>{};

    final String contents = switch (format) {
      ExportFormat.csv => buildCsv(days),
      ExportFormat.json => buildJson(
        days,
        isPreview: isPreview,
        sessions: sessions,
      ),
    };
    final String name =
        '${isPreview ? 'tempo-preview' : 'tempo'}-usage-'
        '${_date.format(today)}.${format.extension}';

    return ExportResult(
      path: await ShareService.saveText(contents, name),
      days: recorded,
    );
  }

  static String buildCsv(List<DaySummary> days) {
    final StringBuffer buffer = StringBuffer()
      ..writeln(
        'date,active_seconds,idle_seconds,sessions,'
        'longest_session_seconds,application,application_id,'
        'application_seconds',
      );
    for (final DaySummary day in days) {
      if (day.isEmpty) {
        continue;
      }
      final String prefix =
          '${_date.format(day.date)},${day.active.inSeconds},'
          '${day.idle.inSeconds},${day.sessions},'
          '${day.longestSession.inSeconds}';
      if (day.apps.isEmpty) {
        buffer.writeln('$prefix,,,');
        continue;
      }
      for (final AppUsage app in day.apps) {
        buffer.writeln(
          '$prefix,${_field(app.name)},${_field(app.id)},'
          '${app.duration.inSeconds}',
        );
      }
    }
    return buffer.toString();
  }

  static Map<String, List<UsageSession>> _byDay(List<UsageSession> sessions) {
    final Map<String, List<UsageSession>> grouped =
        <String, List<UsageSession>>{};
    for (final UsageSession session in sessions) {
      grouped
          .putIfAbsent(UsageDao.dayKey(session.day), () => <UsageSession>[])
          .add(session);
    }
    return grouped;
  }

  static String buildJson(
    List<DaySummary> days, {
    required bool isPreview,
    Map<String, List<UsageSession>> sessions = const <String, List<UsageSession>>{},
  }) {
    final Map<String, Object?> payload = <String, Object?>{
      'application': AppInfo.name,
      'version': AppInfo.version,
      'exported': DateTime.now().toIso8601String(),
      'previewData': isPreview,
      'note':
          'Daily roll-ups, with the sessions behind them where they exist. '
          'Tempo can import this file back.',
      'days': <Map<String, Object?>>[
        for (final DaySummary day in days)
          if (!day.isEmpty)
            <String, Object?>{
              'date': _date.format(day.date),
              'activeSeconds': day.active.inSeconds,
              'idleSeconds': day.idle.inSeconds,
              'sessionCount': day.sessions,
              'longestSessionSeconds': day.longestSession.inSeconds,
              'activeMinutesByHour': <double>[
                for (final double minutes in day.activeMinutesByHour)
                  double.parse(minutes.toStringAsFixed(2)),
              ],
              'applications': <Map<String, Object?>>[
                for (final AppUsage app in day.apps)
                  <String, Object?>{
                    'id': app.id,
                    'name': app.name,
                    'seconds': app.duration.inSeconds,
                  },
              ],
              'sessions': <Map<String, Object?>>[
                for (final UsageSession session
                    in sessions[_date.format(day.date)] ??
                        const <UsageSession>[])
                  <String, Object?>{
                    'applicationId': session.applicationId,
                    'applicationName': session.applicationName,
                    'startMs': session.start.millisecondsSinceEpoch,
                    'endMs': session.end.millisecondsSinceEpoch,
                    'platform': session.platform,
                  },
              ],
            },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Quotes a value if it could otherwise break the row.
  static String _field(String value) {
    if (!value.contains(',') && !value.contains('"') && !value.contains('\n')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }
}
