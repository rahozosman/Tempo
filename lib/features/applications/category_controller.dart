import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/tempo_log.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../data/database/tempo_database.dart';
import '../../domain/analytics/app_category.dart';
import '../../domain/analytics/app_usage.dart';

/// How a period splits across categories.
@immutable
class CategoryBreakdown {
  const CategoryBreakdown({required this.totals, required this.total});

  /// Built from a ranked application list and the current category map.
  factory CategoryBreakdown.of(
    Iterable<AppUsage> apps,
    Map<String, AppCategory> categories,
  ) {
    final Map<AppCategory, int> seconds = <AppCategory, int>{};
    int total = 0;
    for (final AppUsage app in apps) {
      final AppCategory category =
          categories[app.id] ?? AppCategoryDefaults.forApplication(app.id);
      seconds[category] = (seconds[category] ?? 0) + app.duration.inSeconds;
      total += app.duration.inSeconds;
    }

    final List<MapEntry<AppCategory, int>> ordered =
        seconds.entries.toList()
          ..sort(
            (MapEntry<AppCategory, int> a, MapEntry<AppCategory, int> b) =>
                b.value.compareTo(a.value),
          );

    return CategoryBreakdown(
      totals: <AppCategory, Duration>{
        for (final MapEntry<AppCategory, int> entry in ordered)
          entry.key: Duration(seconds: entry.value),
      },
      total: Duration(seconds: total),
    );
  }

  /// Heaviest first.
  final Map<AppCategory, Duration> totals;

  final Duration total;

  bool get isEmpty => total.inSeconds <= 0;

  Duration of(AppCategory category) => totals[category] ?? Duration.zero;

  double shareOf(AppCategory category) => total.inSeconds <= 0
      ? 0
      : of(category).inSeconds / total.inSeconds;

  /// Time in applications that count as focused work.
  Duration get focus {
    int seconds = 0;
    for (final MapEntry<AppCategory, Duration> entry in totals.entries) {
      if (entry.key.isFocus) {
        seconds += entry.value.inSeconds;
      }
    }
    return Duration(seconds: seconds);
  }

  double get focusShare =>
      total.inSeconds <= 0 ? 0 : focus.inSeconds / total.inSeconds;

  AppCategory? get leading => totals.isEmpty ? null : totals.keys.first;
}

/// Bumped when a category is changed, so every screen re-reads.
class CategoryRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final NotifierProvider<CategoryRevision, int> categoryRevisionProvider =
    NotifierProvider<CategoryRevision, int>(CategoryRevision.new);

/// The category of every application Tempo knows about: the defaults, with any
/// corrections laid over them.
final FutureProvider<Map<String, AppCategory>> applicationCategoriesProvider =
    FutureProvider<Map<String, AppCategory>>((Ref ref) async {
      ref.watch(categoryRevisionProvider);
      final TempoDatabase? database = ref.watch(databaseProvider);
      if (database == null) {
        return const <String, AppCategory>{};
      }
      try {
        return await database.categories.overrides();
      } on Object catch (error) {
        TempoLog.error('categories could not be read', error);
        return const <String, AppCategory>{};
      }
    });

/// The category one application belongs to right now.
AppCategory categoryOf(String id, Map<String, AppCategory> categories) =>
    categories[id] ?? AppCategoryDefaults.forApplication(id);

/// Moves an application to a category and tells the screens.
void setApplicationCategory(WidgetRef ref, String id, AppCategory category) {
  final TempoDatabase? database = ref.read(databaseProvider);
  if (database == null) {
    return;
  }
  unawaited(
    database.categories
        .set(id, category)
        .then((_) => ref.read(categoryRevisionProvider.notifier).bump())
        .catchError(
          (Object error) =>
              TempoLog.error('could not store a category', error),
        ),
  );
}
