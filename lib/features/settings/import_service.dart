import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../../core/diagnostics/tempo_log.dart';
import '../../data/database/usage_dao.dart';
import '../../domain/tracking/usage_session.dart';

/// What an import did.
@immutable
class ImportResult {
  const ImportResult({
    this.sessions = 0,
    this.days = 0,
    this.cancelled = false,
    this.error,
  });

  const ImportResult.cancelled() : this(cancelled: true);

  const ImportResult.failed(String message) : this(error: message);

  final int sessions;
  final int days;
  final bool cancelled;
  final String? error;

  bool get isSuccess => !cancelled && error == null;
}

/// Reads a Tempo JSON export back into the database.
///
/// The same file can be imported twice without changing anything: a session is
/// the same session if it is the same application starting at the same moment.
/// Days are rebuilt from whatever ends up stored, so totals always match the
/// sessions behind them.
class ImportService {
  const ImportService._();

  static Future<ImportResult> importBackup(UsageDao usage) async {
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        const XTypeGroup(
          label: 'Tempo backup',
          extensions: <String>['json'],
        ),
      ],
    );
    if (file == null) {
      return const ImportResult.cancelled();
    }

    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        return const ImportResult.failed(
          'That file is not a Tempo export.',
        );
      }
      final Object? days = decoded['days'];
      if (days is! List<Object?>) {
        return const ImportResult.failed(
          'That file has no days in it.',
        );
      }

      final List<UsageSession> sessions = <UsageSession>[];
      final Map<DateTime, Duration> idle = <DateTime, Duration>{};
      int dayCount = 0;

      for (final Object? entry in days) {
        if (entry is! Map<String, Object?>) {
          continue;
        }
        dayCount++;
        final DateTime? date = _parseDay(entry['date']);
        final Object? idleSeconds = entry['idleSeconds'];
        if (date != null && idleSeconds is int && idleSeconds > 0) {
          idle[date] = Duration(seconds: idleSeconds);
        }

        final Object? rows = entry['sessions'];
        if (rows is! List<Object?>) {
          continue;
        }
        for (final Object? row in rows) {
          final UsageSession? session = _parseSession(row);
          if (session != null) {
            sessions.add(session);
          }
        }
      }

      if (sessions.isEmpty && idle.isEmpty) {
        return const ImportResult.failed(
          'That export carries totals but no sessions, so there is nothing to '
          'restore from it.',
        );
      }

      final int added = await usage.importSessions(sessions);
      for (final MapEntry<DateTime, Duration> entry in idle.entries) {
        await usage.setIdle(day: entry.key, idle: entry.value);
      }
      return ImportResult(sessions: added, days: dayCount);
    } on Object catch (error, stack) {
      TempoLog.error('import failed', error, stack);
      return ImportResult.failed('That file could not be read: $error');
    }
  }

  static DateTime? _parseDay(Object? value) {
    if (value is! String || value.length < 10) {
      return null;
    }
    return DateTime.tryParse(value.substring(0, 10));
  }

  static UsageSession? _parseSession(Object? row) {
    if (row is! Map<String, Object?>) {
      return null;
    }
    final Object? id = row['applicationId'];
    final Object? start = row['startMs'];
    final Object? end = row['endMs'];
    if (id is! String || start is! int || end is! int || end < start) {
      return null;
    }
    return UsageSession(
      applicationId: id,
      applicationName: row['applicationName'] is String
          ? row['applicationName']! as String
          : id,
      start: DateTime.fromMillisecondsSinceEpoch(start),
      end: DateTime.fromMillisecondsSinceEpoch(end),
      platform: row['platform'] is String
          ? row['platform']! as String
          : 'imported',
    );
  }
}
