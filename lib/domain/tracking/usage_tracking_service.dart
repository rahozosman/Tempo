import 'dart:async';


import '../../core/diagnostics/tempo_log.dart';
import '../../data/database/usage_dao.dart';
import '../../platform/usage_tracking/usage_tracking_platform.dart';
import 'tracking_status.dart';
import 'usage_session.dart';

/// The engine: it watches which application is in front, turns that into
/// sessions, and writes them down.
///
/// The rule it is built on is that **Tempo only records time it actually
/// watched**. Nothing is inferred from a gap, a clock reading, or a machine
/// that was not running.
///
///  * **Cost.** It samples every few seconds and writes about once a minute.
///    The session it holds open is updated in place rather than written again,
///    so a two-hour stretch is one row, not a hundred.
///  * **Idle.** Time the machine is awake but untouched is not counted towards
///    any application. The session closes at the moment input actually
///    stopped, not when the timeout expired, and only the part of the interval
///    Tempo was watching is counted as idle.
///  * **Sleep, suspension and clock changes.** A stopwatch runs beside the
///    wall clock. The stopwatch cannot be set by hand and does not run while
///    the machine sleeps, so the two disagreeing is how Tempo knows the
///    machine stopped or the clock moved. Either way the open session closes
///    at the last moment actually observed, and the gap counts as nothing.
///  * **Lock and wake.** Where the system announces sleeping, waking and
///    locking, measurement stops and starts at that moment rather than at the
///    next sample.
///  * **Midnight.** A session never crosses a day boundary: it closes at
///    midnight and a new one opens, so a day's totals are always whole.
class UsageTrackingService {
  UsageTrackingService({
    required this.platform,
    required this.usage,
    required this.idleTimeout,
    required this.onUsageChanged,
    required this.onStatusChanged,
  });

  final UsageTrackingPlatform platform;

  /// Null when the database could not be opened; the engine then reports that
  /// it is unavailable rather than measuring into nothing.
  final UsageDao? usage;

  /// Read on every sample, so changing it in Settings takes effect at once.
  final Duration Function() idleTimeout;

  final void Function() onUsageChanged;
  final void Function(TrackingStatus status) onStatusChanged;

  /// How often the foreground application is sampled.
  static const Duration sampleInterval = Duration(seconds: 5);

  /// How often the open session is written down.
  static const Duration checkpointInterval = Duration(seconds: 60);

  /// How often the screens are told to re-read.
  static const Duration refreshInterval = Duration(seconds: 30);

  /// How far the wall clock and the stopwatch may disagree before Tempo treats
  /// it as sleep or a clock change rather than ordinary jitter.
  static const Duration driftTolerance = Duration(seconds: 20);

  /// Anything shorter is a flick through a window, not use of an application.
  static const Duration minimumSession = Duration(seconds: 4);

  final Stopwatch _monotonic = Stopwatch();

  Timer? _timer;
  StreamSubscription<SystemEvent>? _systemEvents;

  bool _running = false;
  bool _paused = false;
  bool _working = false;

  /// True between a sleep or lock and the wake or unlock that follows.
  bool _suspended = false;

  UsageSession? _open;
  int? _openRow;
  DateTime? _lastSample;
  Duration? _lastElapsed;
  DateTime? _lastWrite;
  DateTime? _lastRefresh;

  bool _idle = false;
  DateTime _day = _startOfDay(DateTime.now());
  Duration _idleToday = Duration.zero;

  bool get isRunning => _running && !_paused;

  /// The stretch being measured right now, if any. Read by the notification
  /// rules so they can talk about what is actually happening.
  UsageSession? get currentSession => _open;

  TrackingStatus get status {
    if (!platform.isSupported || usage == null) {
      return TrackingStatus.unavailable;
    }
    if (!_running) {
      return TrackingStatus.notStarted;
    }
    return _paused ? TrackingStatus.paused : TrackingStatus.active;
  }

  /// Begins measuring. Safe to call more than once.
  Future<void> start() async {
    if (_running) {
      return;
    }
    final UsageDao? dao = usage;
    if (!platform.isSupported || dao == null) {
      onStatusChanged(TrackingStatus.unavailable);
      return;
    }

    // Today's idle total is read back so a restart continues the day rather
    // than starting it again from zero.
    try {
      _day = _startOfDay(DateTime.now());
      _idleToday = (await dao.day(_day)).idle;
    } on Object catch (error) {
      TempoLog.error('could not read today before tracking · $error');
    }

    _running = true;
    _paused = false;
    _suspended = false;
    _lastWrite = DateTime.now();
    _forgetLastSample();
    _monotonic
      ..reset()
      ..start();
    _systemEvents ??= platform.systemEvents.listen(
      _onSystemEvent,
      onError: (Object error) =>
          TempoLog.error('system event stream failed · $error'),
    );
    _timer = Timer.periodic(sampleInterval, (Timer _) => unawaited(_sample()));
    onStatusChanged(status);
    await _sample();
  }

  /// Writes down whatever is open right now without stopping.
  ///
  /// Used when something else needs the record to be current — the end of a
  /// focus block, for instance, which is measured from stored sessions.
  Future<void> flush() async {
    if (!isRunning) {
      return;
    }
    await _checkpoint(DateTime.now());
  }

  /// Stops measuring and writes down whatever was open.
  Future<void> stop() async {
    if (!_running) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    _monotonic.stop();
    _running = false;
    await _closeOpen(DateTime.now());
    await _writeIdle();
    onUsageChanged();
    onStatusChanged(status);
  }

  /// Stops recording without forgetting that tracking is meant to be on.
  Future<void> pause() async {
    if (!_running || _paused) {
      return;
    }
    _paused = true;
    await _closeOpen(DateTime.now());
    await _writeIdle();
    onUsageChanged();
    onStatusChanged(status);
  }

  Future<void> resume() async {
    if (!_running) {
      return start();
    }
    if (!_paused) {
      return;
    }
    _paused = false;
    _forgetLastSample();
    onStatusChanged(status);
    await _sample();
  }

  Future<void> togglePause() => _paused || !_running ? resume() : pause();

  /// Turns measurement on or off from anywhere — Settings, the sidebar pill,
  /// or the choice made on first run.
  Future<void> setEnabled({required bool enabled}) async {
    if (enabled) {
      return resume();
    }
    if (_running) {
      return pause();
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _systemEvents?.cancel();
    _systemEvents = null;
    _monotonic.stop();
    if (_running) {
      _running = false;
      await _closeOpen(DateTime.now());
      await _writeIdle();
    }
  }

  /// Sleep, wake and lock, as the system announced them.
  Future<void> _onSystemEvent(SystemEvent event) async {
    switch (event) {
      case SystemEvent.sleep:
      case SystemEvent.lock:
        if (_suspended) {
          return;
        }
        _suspended = true;
        await _closeOpen(DateTime.now());
        await _writeIdle();
        onUsageChanged();
      case SystemEvent.wake:
      case SystemEvent.unlock:
        if (!_suspended) {
          return;
        }
        _suspended = false;
        _forgetLastSample();
        await _sample();
    }
  }

  Future<void> _sample() async {
    if (!isRunning || _working || _suspended || usage == null) {
      return;
    }
    _working = true;
    try {
      final DateTime now = DateTime.now();
      final DateTime? previous = _lastSample;
      final Duration elapsed = _monotonic.elapsed;
      final Duration? lastElapsed = _lastElapsed;
      _lastSample = now;
      _lastElapsed = elapsed;

      // The wall clock can be set by hand, corrected by the network or shifted
      // by a time zone; the stopwatch cannot, and it stops while the machine
      // sleeps. When the two disagree, the machine was not being watched.
      bool observed = previous != null && lastElapsed != null;
      if (observed) {
        final Duration wall = now.difference(previous);
        final Duration drift = wall - (elapsed - lastElapsed);
        if (wall.isNegative ||
            drift.abs() > driftTolerance ||
            wall > sampleInterval + driftTolerance) {
          await _closeOpen(wall.isNegative ? (_open?.end ?? now) : previous);
          _idle = false;
          observed = false;
        }
      }

      // A new day starts with its own totals; the open session ends at
      // midnight so no session spans two days.
      final DateTime today = _startOfDay(now);
      if (!today.isAtSameMomentAs(_day)) {
        await _closeOpen(today);
        await _writeIdle();
        _day = today;
        _idleToday = Duration.zero;
        _idle = false;
        onUsageChanged();
      }

      final Duration timeout = idleTimeout();
      final Duration idleFor = timeout == Duration.zero
          ? Duration.zero
          : await platform.idleTime();

      if (timeout > Duration.zero && idleFor >= timeout) {
        await _goIdle(
          now: now,
          since: observed ? previous : null,
          idleFor: idleFor,
        );
      } else {
        _idle = false;
        await _followForeground(now);
      }

      if (_lastWrite == null ||
          now.difference(_lastWrite!) >= checkpointInterval) {
        await _checkpoint(now);
      }
    } on Object catch (error, stack) {
      TempoLog.error('tracking sample failed', error, stack);
    } finally {
      _working = false;
    }
  }

  /// The machine is awake but untouched.
  ///
  /// [since] is the previous sample, when there was one worth trusting. Only
  /// the stretch between it and now can be counted: anything earlier is time
  /// Tempo was not watching, and inventing it would put a lie in the totals.
  Future<void> _goIdle({
    required DateTime now,
    required DateTime? since,
    required Duration idleFor,
  }) async {
    final DateTime began = now.subtract(idleFor);
    if (!_idle) {
      // Close the session where input actually stopped, not where the timeout
      // expired.
      await _closeOpen(began);
      _idle = true;
    }
    if (since == null) {
      return;
    }

    DateTime from = since;
    if (began.isAfter(from)) {
      from = began;
    }
    if (from.isBefore(_day)) {
      from = _day;
    }
    final Duration slice = now.difference(from);
    if (slice > Duration.zero) {
      _idleToday += slice;
    }
  }

  Future<void> _followForeground(DateTime now) async {
    final ActiveApplication? application = await platform.activeApplication();
    if (application == null) {
      await _closeOpen(now);
      return;
    }

    final UsageSession? open = _open;
    if (open != null && open.applicationId == application.id) {
      _open = open.copyWith(end: now);
      return;
    }

    await _closeOpen(now);
    _open = UsageSession(
      applicationId: application.id,
      applicationName: application.name,
      start: now,
      end: now,
      platform: platform.platformName,
    );
    _openRow = null;
  }

  /// Writes the open session and the day's idle total.
  Future<void> _checkpoint(DateTime now) async {
    final UsageDao? dao = usage;
    if (dao == null) {
      return;
    }
    final UsageSession? open = _open;
    if (open != null && open.duration >= minimumSession) {
      _openRow = await dao.saveSession(open.copyWith(end: now), id: _openRow);
    }
    await _writeIdle();
    _lastWrite = now;
    _refresh(now);
  }

  Future<void> _closeOpen(DateTime at) async {
    final UsageDao? dao = usage;
    final UsageSession? open = _open;
    _open = null;
    final int? row = _openRow;
    _openRow = null;
    if (open == null || dao == null) {
      return;
    }

    final DateTime end = at.isBefore(open.start) ? open.start : at;
    final UsageSession finished = open.copyWith(end: end);
    // A session too short to mean anything is dropped, unless it has already
    // been written, in which case the row is corrected rather than left wrong.
    if (finished.duration < minimumSession && row == null) {
      return;
    }
    try {
      await dao.saveSession(finished, id: row);
      _lastWrite = DateTime.now();
      _refresh(_lastWrite!);
    } on Object catch (error) {
      TempoLog.error('could not store a session · $error');
    }
  }

  Future<void> _writeIdle() async {
    final UsageDao? dao = usage;
    if (dao == null) {
      return;
    }
    try {
      await dao.setIdle(day: _day, idle: _idleToday);
    } on Object catch (error) {
      TempoLog.error('could not store idle time · $error');
    }
  }

  /// After a pause, a wake or a clock change there is no interval worth
  /// trusting, so the next sample starts fresh.
  void _forgetLastSample() {
    _lastSample = null;
    _lastElapsed = null;
    _idle = false;
  }

  /// Tells the screens to re-read, but not more often than they can usefully
  /// change.
  void _refresh(DateTime now) {
    final DateTime? last = _lastRefresh;
    if (last != null && now.difference(last) < refreshInterval) {
      return;
    }
    _lastRefresh = now;
    onUsageChanged();
  }

  static DateTime _startOfDay(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);
}
