import '../../domain/analytics/analytics_repository.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/tracking/usage_session.dart';
import '../database/tempo_database.dart';

/// The production repository: everything the screens show comes from the
/// local database, and nothing else.
class SqliteAnalyticsRepository extends AnalyticsRepository {
  const SqliteAnalyticsRepository(this._database);

  final TempoDatabase _database;

  @override
  Future<DaySummary> day(DateTime date) => _database.usage.day(date);

  @override
  Future<List<DaySummary>> days(DateTime from, DateTime to) =>
      _database.usage.days(from, to);

  @override
  Future<List<UsageSession>> sessions(DateTime day) =>
      _database.usage.sessionsBetween(day, day);

  @override
  Future<DateTime?> earliestDay() => _database.usage.earliestDay();
}

/// Stands in when the database could not be opened.
///
/// Every call fails, on purpose: the screens then show their storage error
/// instead of an empty week that looks like a quiet one.
class UnavailableAnalyticsRepository extends AnalyticsRepository {
  const UnavailableAnalyticsRepository();

  @override
  Future<DaySummary> day(DateTime date) async => throw const StorageFailure();

  @override
  Future<List<DaySummary>> days(DateTime from, DateTime to) async =>
      throw const StorageFailure();

  @override
  Future<List<UsageSession>> sessions(DateTime day) async =>
      throw const StorageFailure();

  @override
  Future<DateTime?> earliestDay() async => throw const StorageFailure();
}

class StorageFailure implements Exception {
  const StorageFailure();

  @override
  String toString() => 'Tempo could not open its usage database.';
}
