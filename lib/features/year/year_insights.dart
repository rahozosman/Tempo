import 'package:intl/intl.dart';

import '../../core/utilities/tempo_format.dart';
import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/analytics/year_summary.dart';
import '../../shared/widgets/insight_card.dart';
import '../../shared/widgets/tempo_icon.dart';

/// Turns a year of stored days into the sentences shown at the foot of the
/// year screen.
///
/// Every line is derived from the data in [summary]. An observation that
/// cannot be made — no previous year, no recorded day — is left out rather
/// than filled in with something plausible.
List<InsightLine> buildYearInsights(YearSummary summary) {
  if (summary.isEmpty) {
    return const <InsightLine>[];
  }

  final NumberFormat number = NumberFormat.decimalPattern();
  final List<InsightLine> insights = <InsightLine>[];
  final int hours = summary.screenTime.inMinutes ~/ 60;

  insights.add(
    InsightLine(
      glyph: TempoGlyph.clock,
      headline: '${number.format(hours)} hours',
      detail:
          'You spent this long at the computer in ${summary.year}, across '
          '${TempoFormat.count(summary.activeDays, 'day')} with activity.',
    ),
  );

  final AppUsage? mostUsed = summary.mostUsed;
  if (mostUsed != null) {
    insights.add(
      InsightLine(
        glyph: TempoGlyph.apps,
        headline: mostUsed.name,
        detail:
            'Your most-used application, at '
            '${TempoFormat.hm(mostUsed.duration)} — '
            '${TempoFormat.percent(mostUsed.shareOf(summary.activeTime))} of '
            'your active time.',
      ),
    );
  }

  final int? busiestMonth = summary.busiestMonth;
  if (busiestMonth != null) {
    insights.add(
      InsightLine(
        glyph: TempoGlyph.month,
        headline: DateFormat.MMMM().format(
          DateTime(summary.year, busiestMonth + 1),
        ),
        detail:
            'Your busiest month, at '
            '${TempoFormat.hm(summary.monthlyTotals[busiestMonth])} of screen '
            'time.',
      ),
    );
  }

  final double? averageChange = summary.averageChange;
  if (averageChange != null) {
    final int percent = (averageChange.abs() * 100).round();
    insights.add(
      InsightLine(
        glyph: averageChange >= 0
            ? TempoGlyph.trendUp
            : TempoGlyph.trendDown,
        headline: TempoFormat.signedPercent(averageChange),
        detail:
            'Your daily average is $percent% '
            '${averageChange >= 0 ? 'higher' : 'lower'} than in '
            '${summary.year - 1}, at '
            '${TempoFormat.hm(summary.dailyAverage)} a day.',
      ),
    );
  }

  final DaySummary? longestDay = summary.longestSessionDay;
  if (longestDay != null && summary.longestSession > Duration.zero) {
    insights.add(
      InsightLine(
        glyph: TempoGlyph.insights,
        headline: TempoFormat.hm(summary.longestSession),
        detail:
            'Your longest unbroken session, on '
            '${TempoFormat.dayLong(longestDay.date)}.',
      ),
    );
  }

  final DaySummary? busiest = summary.busiest;
  if (busiest != null) {
    insights.add(
      InsightLine(
        glyph: TempoGlyph.today,
        headline: TempoFormat.hm(busiest.total),
        detail:
            'Your heaviest day was '
            '${TempoFormat.dayLong(busiest.date)}.',
      ),
    );
  }

  final int? heaviestWeekday = summary.heaviestWeekday;
  if (heaviestWeekday != null) {
    final DateTime reference = DateTime(2024, 1, 1 + heaviestWeekday);
    insights.add(
      InsightLine(
        glyph: TempoGlyph.week,
        headline: '${DateFormat.EEEE().format(reference)}s',
        detail:
            'Your heaviest weekday, averaging '
            '${TempoFormat.hm(summary.weekdayAverage(heaviestWeekday))}.',
      ),
    );
  }

  final DaySummary? quietest = summary.quietest;
  if (quietest != null && quietest != busiest) {
    insights.add(
      InsightLine(
        glyph: TempoGlyph.pause,
        headline: TempoFormat.hm(quietest.total),
        detail:
            'Your lightest day with any activity was '
            '${TempoFormat.dayLong(quietest.date)}.',
      ),
    );
  }

  insights.add(
    InsightLine(
      glyph: TempoGlyph.year,
      headline: '${summary.activeDays} of ${summary.dayCount}',
      detail:
          'Days you used this computer in ${summary.year}'
          '${summary.isLeapYear ? ', a leap year' : ''}. '
          '${TempoFormat.count(summary.sessions, 'session')} in total.',
    ),
  );

  return insights;
}
