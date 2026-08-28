import 'package:local_notifier/local_notifier.dart';

import '../../core/constants/app_info.dart';
import '../../core/diagnostics/tempo_log.dart';
import '../../core/platform/tempo_platform.dart';
import '../../core/utilities/tempo_format.dart';
import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/tracking/usage_session.dart';

/// Desktop notifications.
///
/// Tempo raises at most a couple a day, states a fact, and never nags: passing
/// a goal is worth knowing, not worth scolding.
class NotificationService {
  NotificationService();

  /// How long in one application before it is worth mentioning.
  static const Duration longStretch = Duration(hours: 2);

  bool _ready = false;

  /// Days are tracked so each notice happens once, and starts fresh tomorrow.
  DateTime? _day;
  bool _goalAnnounced = false;
  final Set<String> _stretchesAnnounced = <String>{};
  final Set<String> _limitsAnnounced = <String>{};

  bool get isSupported => TempoPlatform.isWindows || TempoPlatform.isMacOS;

  /// Registers the application with the system notification centre. On Windows
  /// this also needs a Start-menu shortcut, which the plugin creates.
  Future<void> setup() async {
    if (!isSupported || _ready) {
      return;
    }
    try {
      await localNotifier.setup(appName: AppInfo.name);
      _ready = true;
    } on Object catch (error) {
      TempoLog.error('notifications unavailable · $error');
    }
  }

  Future<void> show(String title, String body) async {
    if (!_ready) {
      return;
    }
    try {
      await localNotifier.notify(
        LocalNotification(title: title, body: body),
      );
    } on Object catch (error) {
      TempoLog.error('could not show a notification · $error');
    }
  }

  /// Decides whether today has crossed anything worth saying, and says it.
  ///
  /// Every message is built from measured time; nothing is predicted and
  /// nothing is repeated within a day.
  Future<void> review({
    required bool enabled,
    required DaySummary today,
    required Duration goal,
    required UsageSession? openSession,
    Map<String, Duration> limits = const <String, Duration>{},
  }) async {
    if (!enabled || !_ready) {
      return;
    }
    _rollDay(today.date);

    if (!_goalAnnounced &&
        goal > Duration.zero &&
        today.total >= goal &&
        today.total.inSeconds > 0) {
      _goalAnnounced = true;
      final Duration over = today.total - goal;
      await show(
        'Today has reached your goal',
        over.inMinutes < 1
            ? '${TempoFormat.hm(today.total)} of screen time, against a goal '
                  'of ${TempoFormat.hm(goal)}.'
            : '${TempoFormat.hm(today.total)} so far — '
                  '${TempoFormat.hm(over)} past the '
                  '${TempoFormat.hm(goal)} you set.',
      );
    }

    // A limit reached is said once, on the day it happens.
    for (final AppUsage app in today.apps) {
      final Duration? limit = limits[app.id];
      if (limit == null ||
          limit <= Duration.zero ||
          app.duration < limit ||
          _limitsAnnounced.contains(app.id)) {
        continue;
      }
      _limitsAnnounced.add(app.id);
      await show(
        '${app.name} has reached its limit',
        '${TempoFormat.hm(app.duration)} today, against the '
            '${TempoFormat.hm(limit)} you set.',
      );
    }

    final UsageSession? session = openSession;
    if (session != null &&
        session.duration >= longStretch &&
        !_stretchesAnnounced.contains(session.applicationId)) {
      _stretchesAnnounced.add(session.applicationId);
      await show(
        '${TempoFormat.hm(session.duration)} in ${session.applicationName}',
        'That is one unbroken stretch. Worth a pause, if it suits you.',
      );
    }
  }

  void _rollDay(DateTime date) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    if (_day != null && _day!.isAtSameMomentAs(day)) {
      return;
    }
    _day = day;
    _goalAnnounced = false;
    _stretchesAnnounced.clear();
    _limitsAnnounced.clear();
  }
}
