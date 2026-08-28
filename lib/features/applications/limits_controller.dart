import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/tempo_log.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../data/database/tempo_database.dart';
import '../../domain/analytics/app_usage.dart';

/// Bumped when a limit is set or cleared.
class LimitRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final NotifierProvider<LimitRevision, int> limitRevisionProvider =
    NotifierProvider<LimitRevision, int>(LimitRevision.new);

/// The daily ceiling for each application that has one.
///
/// Applications without a limit are simply absent, so an empty map means Tempo
/// is watching nothing in particular — which is the default.
final FutureProvider<Map<String, Duration>> applicationLimitsProvider =
    FutureProvider<Map<String, Duration>>((Ref ref) async {
      ref.watch(limitRevisionProvider);
      final TempoDatabase? database = ref.watch(databaseProvider);
      if (database == null) {
        return const <String, Duration>{};
      }
      try {
        return await database.limits.all();
      } on Object catch (error) {
        TempoLog.error('limits could not be read', error);
        return const <String, Duration>{};
      }
    });

/// Sets a daily limit, or clears it when [limit] is null.
void setApplicationLimit(WidgetRef ref, String id, Duration? limit) {
  final TempoDatabase? database = ref.read(databaseProvider);
  if (database == null) {
    return;
  }
  final Future<void> write = limit == null || limit <= Duration.zero
      ? database.limits.clear(id)
      : database.limits.set(id, limit);
  unawaited(
    write
        .then((_) => ref.read(limitRevisionProvider.notifier).bump())
        .catchError(
          (Object error) => TempoLog.error('could not store a limit', error),
        ),
  );
}

/// How one application stands against its limit today.
class LimitProgress {
  const LimitProgress({
    required this.usage,
    required this.limit,
  });

  final AppUsage usage;
  final Duration limit;

  double get share => limit.inSeconds <= 0
      ? 0
      : (usage.duration.inSeconds / limit.inSeconds).clamp(0.0, 1.0);

  bool get reached => usage.duration >= limit;

  Duration get remaining => reached
      ? Duration.zero
      : limit - usage.duration;

  Duration get over => reached ? usage.duration - limit : Duration.zero;
}

/// The applications with a limit, worst standing first, for the day given.
List<LimitProgress> limitsFor(
  Iterable<AppUsage> apps,
  Map<String, Duration> limits,
) {
  final List<LimitProgress> progress = <LimitProgress>[
    for (final AppUsage app in apps)
      if (limits.containsKey(app.id))
        LimitProgress(usage: app, limit: limits[app.id]!),
  ];
  progress.sort(
    (LimitProgress a, LimitProgress b) => b.share.compareTo(a.share),
  );
  return progress;
}
