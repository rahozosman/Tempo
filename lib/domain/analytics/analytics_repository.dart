import '../tracking/usage_session.dart';
import 'day_summary.dart';

/// Read access to measured usage.
///
/// The interface is deliberately date-based: it is the shape a SQLite-backed
/// implementation wants, and it keeps every screen unaware of where the numbers
/// came from.
abstract class AnalyticsRepository {
  const AnalyticsRepository();

  /// The summary for one calendar day. Days with nothing recorded come back as
  /// [DaySummary.empty] rather than null, so callers never branch on absence.
  Future<DaySummary> day(DateTime date);

  /// Inclusive range, oldest first. [from] and [to] are treated as local days.
  Future<List<DaySummary>> days(DateTime from, DateTime to);

  /// Every session of one day, in the order they happened.
  ///
  /// Summaries answer "how long"; this answers "when", which is what the day
  /// timeline is drawn from.
  Future<List<UsageSession>> sessions(DateTime day);

  /// The first day with anything recorded, or null when nothing has been
  /// measured yet. Year navigation uses this to know how far back to offer.
  Future<DateTime?> earliestDay();
}
