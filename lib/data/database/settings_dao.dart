import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Preferences, stored beside the usage history rather than in a second place.
class SettingsDao {
  const SettingsDao(this._database);

  final Database _database;

  static const String table = 'settings';

  /// Every stored preference. Read once at startup so controllers can begin
  /// with the right value instead of flickering to it.
  Future<Map<String, String>> all() async {
    final List<Map<String, Object?>> rows = await _database.query(table);
    return <String, String>{
      for (final Map<String, Object?> row in rows)
        row['key']! as String: row['value']! as String,
    };
  }

  /// One stored preference, or null when it has never been set.
  Future<String?> get(String key) async {
    final List<Map<String, Object?>> rows = await _database.query(
      table,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) => _database.insert(
    table,
    <String, Object?>{'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> remove(String key) =>
      _database.delete(table, where: 'key = ?', whereArgs: <Object?>[key]);
}

/// The keys Tempo stores, in one place so nothing is written under a name
/// nothing else reads.
class SettingsKeys {
  const SettingsKeys._();

  static const String themeMode = 'appearance.theme_mode';
  static const String accentIntensity = 'appearance.accent_intensity';
  static const String dailyGoalMinutes = 'screen_time.daily_goal_minutes';
  static const String idleTimeoutMinutes = 'tracking.idle_timeout_minutes';
  static const String trackingEnabled = 'tracking.enabled';
  static const String onboardingCompleted = 'onboarding.completed';
  static const String keepRunning = 'general.keep_running';
  static const String notifications = 'general.notifications';
  static const String retentionDays = 'data.retention_days';
  static const String weeklyDigest = 'general.weekly_digest';
  static const String lastWeeklyDigest = 'general.last_weekly_digest';
  static const String includeApplicationNames = 'sharing.include_app_names';
}
