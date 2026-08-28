import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/analytics/analytics_providers.dart';
import '../../data/database/settings_dao.dart';
import '../../data/database/tempo_database.dart';

/// Preferences the interface honours, stored in the same database as the usage
/// history rather than in a second place.
@immutable
class TempoPreferences {
  const TempoPreferences({
    this.dailyGoal = const Duration(hours: 6),
    this.includeApplicationNames = true,
    this.idleTimeout = const Duration(minutes: 5),
    this.trackingEnabled = true,
    this.keepRunningInBackground = true,
    this.notificationsEnabled = true,
    this.retentionDays = 0,
    this.weeklyDigest = true,
    this.windowBlur = true,
  });

  /// The screen-time goal shown on Today.
  final Duration dailyGoal;

  /// Whether a shared report names the applications used.
  final bool includeApplicationNames;

  /// How long the machine may sit untouched before Tempo stops counting the
  /// time towards an application. [Duration.zero] never counts anything as
  /// idle.
  final Duration idleTimeout;

  /// Whether Tempo is measuring at all. Kept here so a pause survives a
  /// restart rather than quietly turning itself back on.
  final bool trackingEnabled;

  /// Whether closing the window leaves Tempo measuring from the tray, or
  /// quits it outright.
  final bool keepRunningInBackground;

  /// Whether Tempo may raise a desktop notification.
  final bool notificationsEnabled;

  /// How many days of history to keep. Zero keeps everything, which is the
  /// default: deleting your own past should always be a choice.
  final int retentionDays;

  /// Whether Tempo sends one summary of the week just gone.
  final bool weeklyDigest;

  /// Whether the window itself blurs the desktop behind it, where the system
  /// can do that.
  final bool windowBlur;

  TempoPreferences copyWith({
    Duration? dailyGoal,
    bool? includeApplicationNames,
    Duration? idleTimeout,
    bool? trackingEnabled,
    bool? keepRunningInBackground,
    bool? notificationsEnabled,
    int? retentionDays,
    bool? weeklyDigest,
    bool? windowBlur,
  }) => TempoPreferences(
    dailyGoal: dailyGoal ?? this.dailyGoal,
    includeApplicationNames:
        includeApplicationNames ?? this.includeApplicationNames,
    idleTimeout: idleTimeout ?? this.idleTimeout,
    trackingEnabled: trackingEnabled ?? this.trackingEnabled,
    keepRunningInBackground:
        keepRunningInBackground ?? this.keepRunningInBackground,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    retentionDays: retentionDays ?? this.retentionDays,
    weeklyDigest: weeklyDigest ?? this.weeklyDigest,
    windowBlur: windowBlur ?? this.windowBlur,
  );
}

class PreferencesController extends Notifier<TempoPreferences> {
  static const int _defaultGoalMinutes = 6 * 60;

  @override
  TempoPreferences build() {
    final Map<String, String> stored = ref.read(storedSettingsProvider);
    final int minutes =
        int.tryParse(stored[SettingsKeys.dailyGoalMinutes] ?? '') ??
        _defaultGoalMinutes;
    final int idleMinutes =
        int.tryParse(stored[SettingsKeys.idleTimeoutMinutes] ?? '') ?? 5;
    return TempoPreferences(
      dailyGoal: Duration(minutes: minutes.clamp(30, 16 * 60)),
      includeApplicationNames:
          stored[SettingsKeys.includeApplicationNames] != 'false',
      idleTimeout: Duration(minutes: idleMinutes.clamp(0, 60)),
      trackingEnabled: stored[SettingsKeys.trackingEnabled] != 'false',
      keepRunningInBackground: stored[SettingsKeys.keepRunning] != 'false',
      notificationsEnabled: stored[SettingsKeys.notifications] != 'false',
      retentionDays:
          int.tryParse(stored[SettingsKeys.retentionDays] ?? '') ?? 0,
      weeklyDigest: stored[SettingsKeys.weeklyDigest] != 'false',
      windowBlur: stored[SettingsKeys.windowBlur] != 'false',
    );
  }

  /// Clamped to something a day can hold.
  void setDailyGoal(Duration goal) {
    final int minutes = goal.inMinutes.clamp(30, 16 * 60);
    state = state.copyWith(dailyGoal: Duration(minutes: minutes));
    _remember(SettingsKeys.dailyGoalMinutes, '$minutes');
  }

  void setIncludeApplicationNames(bool value) {
    state = state.copyWith(includeApplicationNames: value);
    _remember(SettingsKeys.includeApplicationNames, '$value');
  }

  /// [Duration.zero] means never: the machine is always counted as in use
  /// while an application is in front.
  void setIdleTimeout(Duration timeout) {
    final int minutes = timeout.inMinutes.clamp(0, 60);
    state = state.copyWith(idleTimeout: Duration(minutes: minutes));
    _remember(SettingsKeys.idleTimeoutMinutes, '$minutes');
  }

  void setTrackingEnabled({required bool enabled}) {
    state = state.copyWith(trackingEnabled: enabled);
    _remember(SettingsKeys.trackingEnabled, '$enabled');
  }

  void setKeepRunningInBackground({required bool enabled}) {
    state = state.copyWith(keepRunningInBackground: enabled);
    _remember(SettingsKeys.keepRunning, '$enabled');
  }

  void setNotificationsEnabled({required bool enabled}) {
    state = state.copyWith(notificationsEnabled: enabled);
    _remember(SettingsKeys.notifications, '$enabled');
  }

  /// Zero keeps everything. Anything else is applied the next time Tempo
  /// starts, and immediately here so the choice is not a promise for later.
  void setRetentionDays(int days) {
    final int value = days < 0 ? 0 : days;
    state = state.copyWith(retentionDays: value);
    _remember(SettingsKeys.retentionDays, '$value');
  }

  void setWeeklyDigest({required bool enabled}) {
    state = state.copyWith(weeklyDigest: enabled);
    _remember(SettingsKeys.weeklyDigest, '$enabled');
  }

  void setWindowBlur({required bool enabled}) {
    state = state.copyWith(windowBlur: enabled);
    _remember(SettingsKeys.windowBlur, '$enabled');
  }

  void _remember(String key, String value) {
    final TempoDatabase? database = ref.read(databaseProvider);
    if (database != null) {
      unawaited(database.settings.set(key, value));
    }
  }
}

final NotifierProvider<PreferencesController, TempoPreferences>
preferencesProvider =
    NotifierProvider<PreferencesController, TempoPreferences>(
      PreferencesController.new,
    );
