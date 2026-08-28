import '../../core/constants/app_info.dart';
import '../../core/utilities/tempo_format.dart';
import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/insight_report.dart';
import '../insights/insights_controller.dart';

/// Builds the plain text a report is shared as.
///
/// Nothing is sent anywhere by this file: it returns a string the person can
/// read, edit and decide what to do with.
String buildShareText({
  required InsightReport report,
  required InsightSpan span,
  required bool includeApplicationNames,
  required bool isPreview,
}) {
  final StringBuffer buffer = StringBuffer();

  if (isPreview) {
    buffer.writeln('⚠ Preview data — not real measurements');
    buffer.writeln();
  }

  buffer
    ..writeln('My screen time — ${span.title}')
    ..writeln(span.describe(report.start, report.end))
    ..writeln()
    ..writeln('Total: ${TempoFormat.hm(report.screenTime)}')
    ..writeln('Daily average: ${TempoFormat.hm(report.dailyAverage)}')
    ..writeln('Active: ${TempoFormat.hm(report.activeTime)}')
    ..writeln('Idle: ${TempoFormat.hm(report.idleTime)}');

  if (report.longestSession > Duration.zero) {
    buffer.writeln(
      'Longest session: ${TempoFormat.hm(report.longestSession)}',
    );
  }

  if (includeApplicationNames && report.apps.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('Top apps:');
    final int count = report.apps.length < 3 ? report.apps.length : 3;
    for (int i = 0; i < count; i++) {
      final AppUsage app = report.apps[i];
      buffer.writeln(
        '${i + 1}. ${app.name} — ${TempoFormat.hm(app.duration)}',
      );
    }
  }

  final double? change = report.change;
  if (change != null) {
    buffer
      ..writeln()
      ..writeln(
        'Change: ${TempoFormat.signedPercent(change)} vs the ${span.previousLabel}',
      );
  }

  buffer
    ..writeln()
    ..writeln('Measured on my own computer with ${AppInfo.name}.');

  return buffer.toString().trimRight();
}
