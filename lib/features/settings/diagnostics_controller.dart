import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../core/diagnostics/tempo_log.dart';
import '../../core/utilities/tempo_format.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../data/database/tempo_database.dart';
import '../../domain/tracking/tracking_status.dart';
import '../../platform/usage_tracking/usage_tracking_platform.dart';
import '../../platform/usage_tracking/usage_tracking_providers.dart';

/// What Tempo can say about its own state.
///
/// The engine fails quietly by nature — a missed reading looks like a quiet
/// afternoon — so this gathers the facts that would otherwise need a debugger:
/// what is stored, whether it is self-consistent, and where the file and the
/// log are.
@immutable
class DiagnosticsReport {
  const DiagnosticsReport({
    required this.platform,
    required this.permission,
    required this.status,
    required this.databasePath,
    required this.databaseBytes,
    required this.sessions,
    required this.days,
    required this.applications,
    required this.earliestDay,
    required this.issues,
    required this.logPath,
    required this.previewData,
  });

  final String platform;
  final TrackingPermission permission;
  final TrackingStatus status;

  final String? databasePath;
  final int databaseBytes;

  final int sessions;
  final int days;
  final int applications;
  final DateTime? earliestDay;

  /// Empty when the stored history checks out.
  final List<String> issues;

  final String? logPath;
  final bool previewData;

  bool get isHealthy => issues.isEmpty && databasePath != null;

  String get databaseSize => databaseBytes <= 0
      ? '—'
      : databaseBytes < 1024 * 1024
      ? '${(databaseBytes / 1024).toStringAsFixed(0)} KB'
      : '${(databaseBytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  /// The whole report as plain text, for pasting into a bug report.
  String toText() {
    final StringBuffer buffer = StringBuffer()
      ..writeln('${AppInfo.name} ${AppInfo.version} diagnostics')
      ..writeln(DateTime.now().toIso8601String())
      ..writeln()
      ..writeln('Platform: $platform')
      ..writeln('Permission: ${permission.name}')
      ..writeln('Tracking: ${status.title} — ${status.detail}')
      ..writeln('Preview data: ${previewData ? 'on' : 'off'}')
      ..writeln()
      ..writeln('Database: ${databasePath ?? 'unavailable'}')
      ..writeln('Size: $databaseSize')
      ..writeln('Sessions: $sessions')
      ..writeln('Days: $days')
      ..writeln('Applications: $applications')
      ..writeln(
        'Earliest day: '
        '${earliestDay == null ? 'none' : TempoFormat.dayLong(earliestDay!)}',
      )
      ..writeln('Log: ${logPath ?? 'unavailable'}')
      ..writeln();

    if (issues.isEmpty) {
      buffer.writeln('Checks: everything consistent.');
    } else {
      buffer.writeln('Checks: ${issues.length} to look at');
      for (final String issue in issues) {
        buffer.writeln('  · $issue');
      }
    }
    return buffer.toString();
  }
}

/// Gathered on demand: refresh it by invalidating this provider.
final FutureProvider<DiagnosticsReport> diagnosticsProvider =
    FutureProvider<DiagnosticsReport>((Ref ref) async {
      ref.watch(usageRevisionProvider);
      final TempoDatabase? database = ref.watch(databaseProvider);
      final UsageTrackingPlatform platform = ref.watch(
        usageTrackingPlatformProvider,
      );

      int bytes = 0;
      Map<String, int> counts = const <String, int>{
        'sessions': 0,
        'days': 0,
        'applications': 0,
      };
      List<String> issues = const <String>[];
      DateTime? earliest;

      if (database != null) {
        try {
          final File file = File(database.path);
          if (file.existsSync()) {
            bytes = await file.length();
          }
          counts = await database.usage.counts();
          issues = await database.usage.integrityIssues();
          earliest = await database.usage.earliestDay();
        } on Object catch (error, stack) {
          TempoLog.error('diagnostics could not be gathered', error, stack);
          issues = <String>['The database could not be inspected: $error'];
        }
      }

      return DiagnosticsReport(
        platform: platform.platformName,
        permission: await platform.permission(),
        status: ref.watch(trackingStatusProvider),
        databasePath: database?.path,
        databaseBytes: bytes,
        sessions: counts['sessions'] ?? 0,
        days: counts['days'] ?? 0,
        applications: counts['applications'] ?? 0,
        earliestDay: earliest,
        issues: issues,
        logPath: TempoLog.path,
        previewData: ref.watch(previewDataProvider),
      );
    });
