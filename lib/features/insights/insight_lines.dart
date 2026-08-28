import '../../core/utilities/tempo_format.dart';
import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/analytics/insight_report.dart';
import '../../shared/widgets/insight_card.dart';
import '../../shared/widgets/tempo_icon.dart';
import 'insights_controller.dart';

/// Turns a span of stored days into the observations shown on Insights.
///
/// Every line comes from the data in [report]; anything that cannot be worked
/// out — no earlier span, no recorded day, no second application — is left out
/// rather than guessed at.
List<InsightLine> buildInsightLines(InsightReport report, InsightSpan span) {
  if (report.isEmpty) {
    return const <InsightLine>[];
  }

  final List<InsightLine> lines = <InsightLine>[
    InsightLine(
      glyph: TempoGlyph.clock,
      headline: TempoFormat.hm(report.screenTime),
      detail:
          'Screen time ${span.title}, across '
          '${TempoFormat.count(report.activeDays, 'day')} with activity.',
    ),
    InsightLine(
      glyph: TempoGlyph.today,
      headline: TempoFormat.hm(report.dailyAverage),
      detail: 'Your average on a day with activity.',
    ),
  ];

  final double? change = report.change;
  if (change != null) {
    lines.add(
      InsightLine(
        glyph: change >= 0 ? TempoGlyph.trendUp : TempoGlyph.trendDown,
        headline: TempoFormat.signedPercent(change),
        detail:
            'Against the same stretch of the ${span.previousLabel}, which came '
            'to ${TempoFormat.hm(report.previousScreenTime)}.',
      ),
    );
  }

  final AppUsage? mostUsed = report.mostUsed;
  if (mostUsed != null) {
    lines.add(
      InsightLine(
        glyph: TempoGlyph.apps,
        headline: mostUsed.name,
        detail:
            'Your most-used application, at '
            '${TempoFormat.hm(mostUsed.duration)} — '
            '${TempoFormat.percent(mostUsed.shareOf(report.activeTime))} of '
            'your active time.',
      ),
    );
  }

  final AppUsage? runnerUp = report.runnerUp;
  if (runnerUp != null) {
    lines.add(
      InsightLine(
        glyph: TempoGlyph.sparkle,
        headline: runnerUp.name,
        detail:
            'Second place, at ${TempoFormat.hm(runnerUp.duration)} '
            '${span.title}.',
      ),
    );
  }

  final DaySummary? busiest = report.busiest;
  if (busiest != null) {
    lines.add(
      InsightLine(
        glyph: TempoGlyph.insights,
        headline: TempoFormat.hm(busiest.total),
        detail: 'Your heaviest day, ${TempoFormat.dayLong(busiest.date)}.',
      ),
    );
  }

  final DaySummary? quietest = report.quietest;
  if (quietest != null && quietest != busiest) {
    lines.add(
      InsightLine(
        glyph: TempoGlyph.pause,
        headline: TempoFormat.hm(quietest.total),
        detail:
            'Your lightest day with any activity, '
            '${TempoFormat.dayLong(quietest.date)}.',
      ),
    );
  }

  final DaySummary? longestDay = report.longestSessionDay;
  if (longestDay != null && report.longestSession > Duration.zero) {
    lines.add(
      InsightLine(
        glyph: TempoGlyph.play,
        headline: TempoFormat.hm(report.longestSession),
        detail:
            'Your longest unbroken session, on '
            '${TempoFormat.dayLong(longestDay.date)}.',
      ),
    );
  }

  if (report.sessions > 0) {
    lines.add(
      InsightLine(
        glyph: TempoGlyph.week,
        headline: TempoFormat.hm(report.averageSession),
        detail:
            'Your average session, across '
            '${TempoFormat.count(report.sessions, 'session')}.',
      ),
    );
  }

  if (report.idleTime > Duration.zero) {
    lines.add(
      InsightLine(
        glyph: TempoGlyph.lock,
        headline: TempoFormat.percent(report.idleShare),
        detail:
            'Of your screen time was idle — the computer awake, but untouched. '
            'None of it counts towards an application.',
      ),
    );
  }

  return lines;
}
