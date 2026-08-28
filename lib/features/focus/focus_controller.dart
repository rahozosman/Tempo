import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/tempo_log.dart';
import '../../core/utilities/tempo_dates.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../data/database/tempo_database.dart';
import '../../domain/analytics/analytics_repository.dart';
import '../../domain/analytics/app_category.dart';
import '../../domain/tracking/focus_block.dart';
import '../../domain/tracking/usage_session.dart';
import '../../platform/usage_tracking/usage_tracking_providers.dart';
import '../applications/category_controller.dart';

/// A focus block, while it is running or just after it finished.
@immutable
class FocusState {
  const FocusState({
    this.target = const Duration(minutes: 25),
    this.startedAt,
    this.elapsed = Duration.zero,
    this.last,
  });

  /// What was asked for.
  final Duration target;

  /// Null when nothing is running.
  final DateTime? startedAt;

  final Duration elapsed;

  /// The block that finished most recently this session.
  final FocusBlock? last;

  bool get isRunning => startedAt != null;

  Duration get remaining {
    final Duration left = target - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  double get progress => target.inSeconds <= 0
      ? 0
      : (elapsed.inSeconds / target.inSeconds).clamp(0.0, 1.0);

  FocusState copyWith({
    Duration? target,
    DateTime? startedAt,
    Duration? elapsed,
    FocusBlock? last,
    bool clearStart = false,
  }) => FocusState(
    target: target ?? this.target,
    startedAt: clearStart ? null : (startedAt ?? this.startedAt),
    elapsed: elapsed ?? this.elapsed,
    last: last ?? this.last,
  );
}

/// Bumped when a block is written, so the history re-reads.
class FocusRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final NotifierProvider<FocusRevision, int> focusRevisionProvider =
    NotifierProvider<FocusRevision, int>(FocusRevision.new);

/// Runs a block of deliberate work.
///
/// Nothing is estimated while it runs: at the end Tempo reads the sessions it
/// actually recorded inside the window and adds up the ones in applications
/// that count as focus. A block that is stopped early is still stored, with
/// the length it really had.
class FocusController extends Notifier<FocusState> {
  Timer? _ticker;

  @override
  FocusState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const FocusState();
  }

  void setTarget(Duration target) {
    if (state.isRunning) {
      return;
    }
    state = state.copyWith(target: target);
  }

  void start() {
    if (state.isRunning) {
      return;
    }
    final DateTime now = DateTime.now();
    state = state.copyWith(startedAt: now, elapsed: Duration.zero);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      final DateTime? started = state.startedAt;
      if (started == null) {
        return;
      }
      final Duration elapsed = DateTime.now().difference(started);
      state = state.copyWith(elapsed: elapsed);
      if (elapsed >= state.target) {
        unawaited(finish());
      }
    });
  }

  /// Ends the block, measures it, and writes it down.
  Future<void> finish() async {
    final DateTime? started = state.startedAt;
    if (started == null) {
      return;
    }
    _ticker?.cancel();
    _ticker = null;

    final DateTime ended = DateTime.now();
    final Duration target = state.target;
    state = state.copyWith(clearStart: true, elapsed: Duration.zero);

    try {
      // Whatever is open right now belongs to this block too.
      await ref.read(usageTrackerProvider).flush();
      final Duration focused = await _focusedWithin(started, ended);
      final FocusBlock block = FocusBlock(
        start: started,
        end: ended,
        target: target,
        focused: focused,
      );
      final TempoDatabase? database = ref.read(databaseProvider);
      if (database != null) {
        await database.focus.add(block);
        ref.read(focusRevisionProvider.notifier).bump();
      }
      state = state.copyWith(last: block);
    } on Object catch (error, stack) {
      TempoLog.error('a focus block could not be measured', error, stack);
    }
  }

  /// Adds up the recorded time inside the window that was spent in an
  /// application whose category counts as focus.
  Future<Duration> _focusedWithin(DateTime from, DateTime to) async {
    final AnalyticsRepository repository = ref.read(
      analyticsRepositoryProvider,
    );
    final Map<String, AppCategory> categories = await ref.read(
      applicationCategoriesProvider.future,
    );

    int seconds = 0;
    // A block can straddle midnight, so both days are read.
    final Set<DateTime> days = <DateTime>{
      TempoDates.startOfDay(from),
      TempoDates.startOfDay(to),
    };
    for (final DateTime day in days) {
      for (final UsageSession session in await repository.sessions(day)) {
        if (!categoryOf(session.applicationId, categories).isFocus) {
          continue;
        }
        final DateTime start = session.start.isAfter(from)
            ? session.start
            : from;
        final DateTime end = session.end.isBefore(to) ? session.end : to;
        if (end.isAfter(start)) {
          seconds += end.difference(start).inSeconds;
        }
      }
    }
    return Duration(seconds: seconds);
  }
}

final NotifierProvider<FocusController, FocusState> focusProvider =
    NotifierProvider<FocusController, FocusState>(FocusController.new);

/// The blocks finished most recently, newest first.
final FutureProvider<List<FocusBlock>> recentFocusProvider =
    FutureProvider<List<FocusBlock>>((Ref ref) async {
      ref.watch(focusRevisionProvider);
      final TempoDatabase? database = ref.watch(databaseProvider);
      if (database == null) {
        return const <FocusBlock>[];
      }
      try {
        return await database.focus.recent(limit: 5);
      } on Object catch (error) {
        TempoLog.error('focus history could not be read', error);
        return const <FocusBlock>[];
      }
    });
