import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/tracking/usage_session.dart';

/// Reads and writes usage.
///
/// Sessions are the record of what happened; the two summary tables are a
/// rebuilt view of them, so a summary can never drift from the sessions it
/// came from — anything that changes a day rebuilds that day.
class UsageDao {
  const UsageDao(this._database);

  final Database _database;

  static const String sessionsTable = 'usage_sessions';
  static const String dailyTable = 'daily_summaries';
  static const String applicationsTable = 'application_summaries';

  /// Local calendar day as `yyyy-MM-dd`. Sorting these strings sorts the days,
  /// which is what the range queries rely on.
  static String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime parseDay(String key) => DateTime(
    int.parse(key.substring(0, 4)),
    int.parse(key.substring(5, 7)),
    int.parse(key.substring(8, 10)),
  );

  // ---------------------------------------------------------------- reading

  Future<DaySummary> day(DateTime date) async {
    final List<DaySummary> result = await days(date, date);
    return result.isEmpty ? DaySummary.empty(date) : result.first;
  }

  /// Inclusive, oldest first. Days with nothing stored come back empty rather
  /// than missing, so charts keep their rhythm.
  Future<List<DaySummary>> days(DateTime from, DateTime to) async {
    final String start = dayKey(from);
    final String end = dayKey(to);

    final List<Map<String, Object?>> dailyRows = await _database.query(
      dailyTable,
      where: 'day BETWEEN ? AND ?',
      whereArgs: <Object?>[start, end],
    );
    final List<Map<String, Object?>> applicationRows = await _database.query(
      applicationsTable,
      where: 'day BETWEEN ? AND ?',
      whereArgs: <Object?>[start, end],
      orderBy: 'seconds DESC',
    );

    final Map<String, List<AppUsage>> applications =
        <String, List<AppUsage>>{};
    for (final Map<String, Object?> row in applicationRows) {
      applications
          .putIfAbsent(row['day']! as String, () => <AppUsage>[])
          .add(
            AppUsage(
              id: row['application_id']! as String,
              name: row['application_name']! as String,
              duration: Duration(seconds: row['seconds']! as int),
            ),
          );
    }

    final Map<String, DaySummary> byDay = <String, DaySummary>{};
    for (final Map<String, Object?> row in dailyRows) {
      final String key = row['day']! as String;
      byDay[key] = DaySummary(
        date: parseDay(key),
        active: Duration(seconds: row['active_seconds']! as int),
        idle: Duration(seconds: row['idle_seconds']! as int),
        sessions: row['session_count']! as int,
        longestSession: Duration(
          seconds: row['longest_session_seconds']! as int,
        ),
        apps: applications[key] ?? const <AppUsage>[],
        activeMinutesByHour: _decodeHours(row['hourly_minutes'] as String?),
      );
    }

    final List<DaySummary> result = <DaySummary>[];
    for (
      DateTime cursor = DateTime(from.year, from.month, from.day);
      !cursor.isAfter(DateTime(to.year, to.month, to.day));
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1)
    ) {
      result.add(byDay[dayKey(cursor)] ?? DaySummary.empty(cursor));
    }
    return result;
  }

  /// The first day with anything on it, or null when the database is empty.
  Future<DateTime?> earliestDay() async {
    final List<Map<String, Object?>> rows = await _database.rawQuery(
      'SELECT MIN(day) AS first FROM $dailyTable '
      'WHERE active_seconds > 0 OR idle_seconds > 0',
    );
    final Object? value = rows.isEmpty ? null : rows.first['first'];
    return value is String ? parseDay(value) : null;
  }

  /// How many days actually hold something, for the delete confirmation.
  Future<int> recordedDays() async {
    final List<Map<String, Object?>> rows = await _database.rawQuery(
      'SELECT COUNT(*) AS days FROM $dailyTable '
      'WHERE active_seconds > 0 OR idle_seconds > 0',
    );
    return rows.isEmpty ? 0 : (rows.first['days'] as int? ?? 0);
  }

  /// How much is stored: sessions, days and distinct applications.
  Future<Map<String, int>> counts() async {
    final List<Map<String, Object?>> rows = await _database.rawQuery(
      'SELECT '
      '(SELECT COUNT(*) FROM $sessionsTable) AS sessions, '
      '(SELECT COUNT(*) FROM $dailyTable) AS days, '
      '(SELECT COUNT(DISTINCT application_id) FROM $applicationsTable) '
      'AS applications',
    );
    if (rows.isEmpty) {
      return const <String, int>{'sessions': 0, 'days': 0, 'applications': 0};
    }
    final Map<String, Object?> row = rows.first;
    return <String, int>{
      'sessions': row['sessions'] as int? ?? 0,
      'days': row['days'] as int? ?? 0,
      'applications': row['applications'] as int? ?? 0,
    };
  }

  /// Checks the invariants the engine is supposed to guarantee, in plain
  /// language. An empty list means the stored history is self-consistent.
  ///
  /// These are the failures that would otherwise look like a quiet day: a
  /// session left open across midnight, two applications counted at once, or a
  /// summary that has drifted from the sessions behind it.
  Future<List<String>> integrityIssues() async {
    final List<String> issues = <String>[];

    Future<int> count(String sql, [List<Object?> args = const <Object?>[]]) async {
      final List<Map<String, Object?>> rows = await _database.rawQuery(
        sql,
        args,
      );
      return rows.isEmpty ? 0 : (rows.first.values.first as int? ?? 0);
    }

    final int spanning = await count(
      "SELECT COUNT(*) FROM $sessionsTable WHERE "
      "date(start_ms / 1000, 'unixepoch', 'localtime') != "
      "date(end_ms / 1000, 'unixepoch', 'localtime')",
    );
    if (spanning > 0) {
      issues.add(
        '$spanning session(s) start on one day and end on another. Sessions '
        'are meant to be closed at midnight.',
      );
    }

    final int badDuration = await count(
      'SELECT COUNT(*) FROM $sessionsTable WHERE duration_seconds <= 0 '
      'OR end_ms < start_ms',
    );
    if (badDuration > 0) {
      issues.add('$badDuration session(s) have no length, or end before they '
          'start.');
    }

    final int future = await count(
      'SELECT COUNT(*) FROM $sessionsTable WHERE end_ms > ?',
      <Object?>[DateTime.now().millisecondsSinceEpoch + 120000],
    );
    if (future > 0) {
      issues.add('$future session(s) end in the future.');
    }

    final int overlapping = await count(
      'SELECT COUNT(*) FROM $sessionsTable a JOIN $sessionsTable b '
      'ON a.id < b.id AND a.day = b.day '
      'AND a.start_ms < b.end_ms AND b.start_ms < a.end_ms',
    );
    if (overlapping > 0) {
      issues.add(
        '$overlapping pair(s) of sessions overlap. Only one application can be '
        'in front at a time.',
      );
    }

    final int drifted = await count(
      'SELECT COUNT(*) FROM $dailyTable d LEFT JOIN ('
      'SELECT day, SUM(duration_seconds) AS total FROM $sessionsTable '
      'GROUP BY day) s ON s.day = d.day '
      'WHERE ABS(d.active_seconds - COALESCE(s.total, 0)) > 2',
    );
    if (drifted > 0) {
      issues.add(
        "$drifted day(s) have a summary that does not match their sessions. "
        'Summaries are meant to be rebuilt from the sessions they cover.',
      );
    }

    final List<Map<String, Object?>> check = await _database.rawQuery(
      'PRAGMA integrity_check',
    );
    final Object? verdict = check.isEmpty
        ? null
        : check.first.values.first;
    if (verdict is String && verdict.toLowerCase() != 'ok') {
      issues.add('SQLite reports a problem with the file: $verdict');
    }

    return issues;
  }

  // ---------------------------------------------------------------- writing

  /// Stores measured sessions and rebuilds every day they touch.
  ///
  /// The tracking engine batches these: nothing is written per tick, only when
  /// an application changes, a session ends, or a checkpoint falls due.
  Future<void> recordSessions(List<UsageSession> sessions) async {
    if (sessions.isEmpty) {
      return;
    }
    await _database.transaction((Transaction txn) async {
      final Batch batch = txn.batch();
      for (final UsageSession session in sessions) {
        batch.insert(sessionsTable, rowOf(session));
      }
      await batch.commit(noResult: true);

      for (final String key in <String>{
        for (final UsageSession session in sessions) dayKey(session.day),
      }) {
        await _rebuildDay(txn, key);
      }
    });
  }

  /// Writes one session and rebuilds its day, returning the row it lives in.
  ///
  /// The tracking engine calls this for the session it currently holds open:
  /// passing the id back on the next call updates that same row instead of
  /// adding another, so a stretch stays one session however often it is
  /// checkpointed, and a crash costs at most the time since the last write.
  Future<int> saveSession(UsageSession session, {int? id}) async {
    late int row;
    await _database.transaction((Transaction txn) async {
      if (id == null) {
        row = await txn.insert(sessionsTable, rowOf(session));
      } else {
        final int updated = await txn.update(
          sessionsTable,
          rowOf(session),
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        row = updated == 0
            ? await txn.insert(sessionsTable, rowOf(session))
            : id;
      }
      await _rebuildDay(txn, dayKey(session.day));
    });
    return row;
  }

  static Map<String, Object?> rowOf(UsageSession session) => <String, Object?>{
    'application_id': session.applicationId,
    'application_name': session.applicationName,
    'start_ms': session.start.millisecondsSinceEpoch,
    'end_ms': session.end.millisecondsSinceEpoch,
    'duration_seconds': session.duration.inSeconds,
    'day': dayKey(session.day),
    'platform': session.platform,
  };

  /// Sets the idle total for a day. Idle belongs to no application, so it is
  /// held on the day itself rather than derived from sessions.
  Future<void> setIdle({required DateTime day, required Duration idle}) =>
      _database.rawInsert(
        'INSERT INTO $dailyTable (day, idle_seconds) VALUES (?, ?) '
        'ON CONFLICT(day) DO UPDATE SET idle_seconds = excluded.idle_seconds',
        <Object?>[dayKey(day), idle.inSeconds],
      );

  /// Every session in a range, oldest first. Used by the export, so a backup
  /// carries the record itself rather than only its totals.
  Future<List<UsageSession>> sessionsBetween(DateTime from, DateTime to) async {
    final List<Map<String, Object?>> rows = await _database.query(
      sessionsTable,
      where: 'day BETWEEN ? AND ?',
      whereArgs: <Object?>[dayKey(from), dayKey(to)],
      orderBy: 'start_ms ASC',
    );
    return <UsageSession>[
      for (final Map<String, Object?> row in rows)
        UsageSession(
          id: row['id'] as int?,
          applicationId: row['application_id']! as String,
          applicationName: row['application_name']! as String,
          start: DateTime.fromMillisecondsSinceEpoch(row['start_ms']! as int),
          end: DateTime.fromMillisecondsSinceEpoch(row['end_ms']! as int),
          platform: row['platform']! as String,
        ),
    ];
  }

  /// Adds sessions from a backup, skipping any already stored.
  ///
  /// A session is the same session if it is the same application starting at
  /// the same moment, so importing the same file twice changes nothing.
  Future<int> importSessions(List<UsageSession> sessions) async {
    if (sessions.isEmpty) {
      return 0;
    }
    int added = 0;
    await _database.transaction((Transaction txn) async {
      final Set<String> days = <String>{
        for (final UsageSession session in sessions) dayKey(session.day),
      };
      final Set<String> existing = <String>{};
      for (final String day in days) {
        final List<Map<String, Object?>> rows = await txn.query(
          sessionsTable,
          columns: <String>['application_id', 'start_ms'],
          where: 'day = ?',
          whereArgs: <Object?>[day],
        );
        for (final Map<String, Object?> row in rows) {
          existing.add(
            '${row['application_id']}@${row['start_ms']}',
          );
        }
      }

      final Batch batch = txn.batch();
      for (final UsageSession session in sessions) {
        final String key =
            '${session.applicationId}@'
            '${session.start.millisecondsSinceEpoch}';
        if (existing.contains(key)) {
          continue;
        }
        existing.add(key);
        batch.insert(sessionsTable, rowOf(session));
        added++;
      }
      await batch.commit(noResult: true);

      for (final String day in days) {
        await _rebuildDay(txn, day);
      }
    });
    return added;
  }

  /// Rewrites the file compactly, reclaiming space left by deletions.
  Future<void> optimise() => _database.execute('VACUUM');

  /// Writes a consistent copy of the whole database to [path].
  ///
  /// `VACUUM INTO` is used rather than copying the file, because the engine
  /// may be mid-write and a plain copy could miss the tail of it.
  Future<void> backupTo(String path) =>
      _database.execute('VACUUM INTO ?', <Object?>[path]);

  /// Removes everything. Returns how many days were dropped.
  Future<int> deleteAll() async {
    final int days = await recordedDays();
    await _database.transaction((Transaction txn) async {
      await txn.delete(sessionsTable);
      await txn.delete(applicationsTable);
      await txn.delete(dailyTable);
    });
    return days;
  }

  /// Removes everything before [day], for keeping only recent history.
  Future<void> deleteBefore(DateTime day) async {
    final String key = dayKey(day);
    await _database.transaction((Transaction txn) async {
      await txn.delete(
        sessionsTable,
        where: 'day < ?',
        whereArgs: <Object?>[key],
      );
      await txn.delete(
        applicationsTable,
        where: 'day < ?',
        whereArgs: <Object?>[key],
      );
      await txn.delete(dailyTable, where: 'day < ?', whereArgs: <Object?>[key]);
    });
  }

  /// Recomputes a day's summaries from the sessions it holds. Idle is left
  /// alone: it is written separately and is not derived from sessions.
  Future<void> _rebuildDay(DatabaseExecutor executor, String day) async {
    final List<Map<String, Object?>> rows = await executor.query(
      sessionsTable,
      columns: <String>[
        'application_id',
        'application_name',
        'start_ms',
        'end_ms',
        'duration_seconds',
      ],
      where: 'day = ?',
      whereArgs: <Object?>[day],
    );

    int active = 0;
    int longest = 0;
    final Map<String, int> perApplication = <String, int>{};
    final Map<String, String> names = <String, String>{};
    final List<double> hours = List<double>.filled(24, 0);

    for (final Map<String, Object?> row in rows) {
      final int seconds = row['duration_seconds']! as int;
      final String id = row['application_id']! as String;
      active += seconds;
      if (seconds > longest) {
        longest = seconds;
      }
      perApplication[id] = (perApplication[id] ?? 0) + seconds;
      names[id] = row['application_name']! as String;
      _spreadOverHours(
        hours,
        DateTime.fromMillisecondsSinceEpoch(row['start_ms']! as int),
        DateTime.fromMillisecondsSinceEpoch(row['end_ms']! as int),
      );
    }

    await executor.rawInsert(
      'INSERT INTO $dailyTable '
      '(day, active_seconds, session_count, longest_session_seconds, '
      'hourly_minutes) VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(day) DO UPDATE SET '
      'active_seconds = excluded.active_seconds, '
      'session_count = excluded.session_count, '
      'longest_session_seconds = excluded.longest_session_seconds, '
      'hourly_minutes = excluded.hourly_minutes',
      <Object?>[
        day,
        active,
        rows.length,
        longest,
        jsonEncode(<double>[
          for (final double minutes in hours)
            double.parse(minutes.toStringAsFixed(3)),
        ]),
      ],
    );

    await executor.delete(
      applicationsTable,
      where: 'day = ?',
      whereArgs: <Object?>[day],
    );
    final Batch batch = executor.batch();
    for (final MapEntry<String, int> entry in perApplication.entries) {
      batch.insert(applicationsTable, <String, Object?>{
        'day': day,
        'application_id': entry.key,
        'application_name': names[entry.key] ?? entry.key,
        'seconds': entry.value,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Adds a session's minutes to each hour it actually touches, so a stretch
  /// from 09:40 to 11:10 lands in three hours rather than one.
  static void _spreadOverHours(
    List<double> hours,
    DateTime start,
    DateTime end,
  ) {
    DateTime cursor = start;
    while (cursor.isBefore(end)) {
      final DateTime nextHour = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        cursor.hour + 1,
      );
      final DateTime slice = nextHour.isBefore(end) ? nextHour : end;
      // A clock going backwards must not trap the loop.
      if (!slice.isAfter(cursor)) {
        break;
      }
      final int index = cursor.hour;
      if (index >= 0 && index < 24) {
        hours[index] += slice.difference(cursor).inSeconds / 60;
      }
      cursor = slice;
    }
  }

  static List<double> _decodeHours(String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return DaySummary.zeroHours;
    }
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! List<Object?>) {
        return DaySummary.zeroHours;
      }
      final List<double> hours = List<double>.filled(24, 0);
      for (int i = 0; i < 24 && i < decoded.length; i++) {
        final Object? value = decoded[i];
        hours[i] = value is num ? value.toDouble() : 0;
      }
      return hours;
    } on FormatException {
      return DaySummary.zeroHours;
    }
  }
}
