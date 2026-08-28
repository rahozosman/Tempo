import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/constants/app_info.dart';
import '../../core/platform/tempo_platform.dart';
import '../../core/utilities/tempo_format.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../domain/analytics/day_summary.dart';
import '../../domain/tracking/tracking_status.dart';
import '../../features/navigation/nav_destination.dart';
import '../../features/navigation/navigation_controller.dart';
import '../../features/settings/preferences_controller.dart';
import '../../core/diagnostics/tempo_log.dart';
import '../../data/database/tempo_database.dart';
import '../../features/applications/limits_controller.dart';
import '../notifications/notification_service.dart';
import '../notifications/weekly_digest.dart';
import '../usage_tracking/usage_tracking_providers.dart';

/// Everything Tempo does outside its own window: the tray icon and its menu,
/// what closing the window means, and the occasional notification.
///
/// It draws nothing. It lives in the shell so it exists exactly as long as the
/// app does, and so the tray always shows what the app itself knows.
class DesktopIntegration extends ConsumerStatefulWidget {
  const DesktopIntegration({super.key});

  @override
  ConsumerState<DesktopIntegration> createState() => _DesktopIntegrationState();
}

class _DesktopIntegrationState extends ConsumerState<DesktopIntegration>
    with TrayListener, WindowListener {
  static const Duration _reviewInterval = Duration(seconds: 45);

  final NotificationService _notifications = NotificationService();

  Timer? _review;
  bool _trayReady = false;
  bool _quitting = false;
  String _todayLabel = '—';
  TrackingStatus _status = TrackingStatus.notStarted;
  bool _trackingEnabled = true;

  @override
  void initState() {
    super.initState();
    if (!TempoPlatform.isDesktop) {
      return;
    }
    trayManager.addListener(this);
    windowManager.addListener(this);
    // Closing is intercepted only while this is here to handle it, so the
    // window can never end up unclosable.
    unawaited(windowManager.setPreventClose(true));
    unawaited(_startTray());
    unawaited(_notifications.setup());
    _review = Timer.periodic(
      _reviewInterval,
      (Timer _) => unawaited(_reviewNotifications()),
    );
  }

  @override
  void dispose() {
    _review?.cancel();
    if (TempoPlatform.isDesktop) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
      unawaited(trayManager.destroy());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watching here is what keeps the tray honest: it says what the app says.
    final TrackingStatus status = ref.watch(trackingStatusProvider);
    final DaySummary? today = ref.watch(todaySummaryProvider).value;
    final bool enabled = ref.watch(
      preferencesProvider.select(
        (TempoPreferences value) => value.trackingEnabled,
      ),
    );
    final String label = today == null ? '—' : TempoFormat.hm(today.total);

    if (status != _status || label != _todayLabel || enabled != _trackingEnabled) {
      _status = status;
      _todayLabel = label;
      _trackingEnabled = enabled;
      unawaited(_updateTray());
    }
    return const SizedBox.shrink();
  }

  Future<void> _startTray() async {
    try {
      await trayManager.setIcon(
        TempoPlatform.isMacOS
            ? 'assets/tray/tray_icon_macos.png'
            : 'assets/tray/tray_icon.ico',
        // The macOS icon is a template: the system inverts it for light and
        // dark menu bars rather than Tempo guessing.
        isTemplate: TempoPlatform.isMacOS,
      );
      _trayReady = true;
      await _updateTray();
    } on Object catch (error) {
      TempoLog.error('tray unavailable · $error');
    }
  }

  Future<void> _updateTray() async {
    if (!_trayReady) {
      return;
    }
    try {
      await trayManager.setToolTip(
        '${AppInfo.name} · $_todayLabel today · ${_status.detail}',
      );
      await trayManager.setContextMenu(
        Menu(
          items: <MenuItem>[
            MenuItem(label: "Today's screen time · $_todayLabel", disabled: true),
            MenuItem.separator(),
            MenuItem(
              label: 'Open ${AppInfo.name}',
              onClick: (MenuItem _) => unawaited(_showWindow()),
            ),
            MenuItem(
              label: 'Settings',
              onClick: (MenuItem _) => unawaited(_openSettings()),
            ),
            MenuItem.separator(),
            MenuItem(
              label: _trackingEnabled ? 'Pause tracking' : 'Resume tracking',
              disabled: _status == TrackingStatus.unavailable,
              onClick: (MenuItem _) => _toggleTracking(),
            ),
            MenuItem.separator(),
            MenuItem(
              label: 'Quit ${AppInfo.name}',
              onClick: (MenuItem _) => unawaited(_quit()),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      TempoLog.error('could not update the tray · $error');
    }
  }

  void _toggleTracking() => ref
      .read(preferencesProvider.notifier)
      .setTrackingEnabled(enabled: !_trackingEnabled);

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _openSettings() async {
    ref.read(navigationProvider.notifier).selectSection(TempoSection.settings);
    await _showWindow();
  }

  /// Writes down whatever is being measured, then really leaves.
  Future<void> _quit() async {
    if (_quitting) {
      return;
    }
    _quitting = true;
    _review?.cancel();
    try {
      await ref.read(usageTrackerProvider).stop();
    } on Object catch (error) {
      TempoLog.error('could not finish the open session · $error');
    }
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    if (_quitting) {
      return;
    }
    final bool keepRunning = ref
        .read(preferencesProvider)
        .keepRunningInBackground;
    // Closing the window either leaves Tempo measuring from the tray or ends
    // it properly — never a process left running with nothing to show for it.
    unawaited(keepRunning ? windowManager.hide() : _quit());
  }

  @override
  void onTrayIconMouseDown() {
    // The menu is the point on macOS; on Windows a left click opens the app.
    unawaited(
      TempoPlatform.isMacOS
          ? trayManager.popUpContextMenu()
          : _showWindow(),
    );
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  Future<void> _reviewNotifications() async {
    if (!mounted) {
      return;
    }
    final TempoPreferences preferences = ref.read(preferencesProvider);
    final DaySummary? today = ref.read(todaySummaryProvider).value;
    if (today == null) {
      return;
    }
    await _notifications.review(
      enabled: preferences.notificationsEnabled,
      today: today,
      goal: preferences.dailyGoal,
      openSession: ref.read(usageTrackerProvider).currentSession,
      limits:
          ref.read(applicationLimitsProvider).value ??
          const <String, Duration>{},
    );

    // Checked on the same beat, but it sends at most once a week: the week it
    // covered is stored, so a restart cannot repeat it.
    final TempoDatabase? database = ref.read(databaseProvider);
    await WeeklyDigest.maybeSend(
      database: database,
      repository: ref.read(analyticsRepositoryProvider),
      notifications: _notifications,
      enabled:
          preferences.notificationsEnabled && preferences.weeklyDigest,
    );
  }
}
