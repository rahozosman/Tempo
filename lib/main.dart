import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/tempo_app.dart';
import 'app/window_setup.dart';
import 'data/analytics/analytics_providers.dart';
import 'core/diagnostics/tempo_log.dart';
import 'data/database/settings_dao.dart';
import 'data/database/tempo_database.dart';
import 'platform/startup/startup_controller.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  await TempoLog.open();
  await configureWindow(startHidden: arguments.contains(hiddenLaunchFlag));
  configureStartup();

  // The database is opened before the first frame so every screen can read it
  // without waiting, and so a failure to open it is known immediately: the app
  // still starts, and says so rather than showing an empty week.
  final TempoDatabase? database = await TempoDatabase.open();
  final Map<String, String> settings = database == null
      ? const <String, String>{}
      : await database.settings.all();

  // Applied on the way in rather than in the background: history the person
  // asked not to keep should not outlive the launch that noticed.
  await _applyRetention(database, settings);

  runApp(
    ProviderScope(
      // The override type is internal to Riverpod, so the list is inferred.
      overrides: [
        databaseProvider.overrideWithValue(database),
        storedSettingsProvider.overrideWithValue(settings),
      ],
      child: const TempoApp(),
    ),
  );
}

/// Drops history older than the retention window, when one is set.
Future<void> _applyRetention(
  TempoDatabase? database,
  Map<String, String> settings,
) async {
  final int days =
      int.tryParse(settings[SettingsKeys.retentionDays] ?? '') ?? 0;
  if (database == null || days <= 0) {
    return;
  }
  final DateTime today = DateTime.now();
  final DateTime cutoff = DateTime(today.year, today.month, today.day - days);
  try {
    await database.usage.deleteBefore(cutoff);
  } on Object catch (error) {
    TempoLog.error('could not apply the retention window', error);
  }
}
