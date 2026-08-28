import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utilities/tempo_dates.dart';
import '../../domain/analytics/analytics_repository.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/analytics/home_overview.dart';
import '../../domain/tracking/usage_session.dart';
import '../database/tempo_database.dart';
import 'preview_analytics_repository.dart';
import 'sqlite_analytics_repository.dart';

/// The open database, or null when it could not be opened.
///
/// Overridden at startup in `main`, so every screen can read it without
/// waiting for a future.
final Provider<TempoDatabase?> databaseProvider = Provider<TempoDatabase?>(
  (Ref ref) => throw StateError('databaseProvider must be overridden'),
);

/// The preferences read from the database before the first frame.
final Provider<Map<String, String>> storedSettingsProvider =
    Provider<Map<String, String>>((Ref ref) => const <String, String>{});

/// Bumped whenever stored usage changes, so every screen re-reads.
///
/// The tracking engine will bump this after each flush; today it is deletion
/// that moves it.
class UsageRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final NotifierProvider<UsageRevision, int> usageRevisionProvider =
    NotifierProvider<UsageRevision, int>(UsageRevision.new);

/// Whether the interface is being fed sample data.
///
/// Only ever true in a debug build: [set] refuses to turn it on anywhere else,
/// so a release of Tempo cannot display anything but real measurements.
class PreviewDataController extends Notifier<bool> {
  @override
  bool build() => kDebugMode;

  void set(bool value) => state = kDebugMode && value;

  void toggle() => set(!state);
}

final NotifierProvider<PreviewDataController, bool> previewDataProvider =
    NotifierProvider<PreviewDataController, bool>(PreviewDataController.new);

/// The single source every screen reads usage from.
final Provider<AnalyticsRepository> analyticsRepositoryProvider =
    Provider<AnalyticsRepository>((Ref ref) {
      if (ref.watch(previewDataProvider)) {
        return const PreviewAnalyticsRepository();
      }
      final TempoDatabase? database = ref.watch(databaseProvider);
      return database == null
          ? const UnavailableAnalyticsRepository()
          : SqliteAnalyticsRepository(database);
    });

/// Today, in full.
final FutureProvider<DaySummary> todaySummaryProvider =
    FutureProvider<DaySummary>((Ref ref) async {
      ref.watch(usageRevisionProvider);
      final AnalyticsRepository repository = ref.watch(
        analyticsRepositoryProvider,
      );
      return repository.day(DateTime.now());
    });

/// Every session of one day, in the order they happened.
///
/// Pass midnight of the day: the family caches by the value it is given.
final daySessionsProvider =
    FutureProvider.family<List<UsageSession>, DateTime>((
      Ref ref,
      DateTime day,
    ) async {
      ref.watch(usageRevisionProvider);
      return ref.watch(analyticsRepositoryProvider).sessions(day);
    });

/// Today plus the two weeks of context the Home dashboard compares against.
final FutureProvider<HomeOverview> homeOverviewProvider =
    FutureProvider<HomeOverview>((Ref ref) async {
      ref.watch(usageRevisionProvider);
      final AnalyticsRepository repository = ref.watch(
        analyticsRepositoryProvider,
      );
      final DateTime today = TempoDates.startOfDay(DateTime.now());
      final List<DaySummary> week = await repository.days(
        DateTime(today.year, today.month, today.day - 6),
        today,
      );
      final List<DaySummary> previous = await repository.days(
        DateTime(today.year, today.month, today.day - 13),
        DateTime(today.year, today.month, today.day - 7),
      );
      return HomeOverview(
        lastSevenDays: week,
        previousSevenDays: previous,
      );
    });
