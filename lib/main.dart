import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/tempo_app.dart';
import 'app/window_effects.dart';
import 'app/window_setup.dart';
import 'data/analytics/analytics_providers.dart';
import 'core/diagnostics/tempo_log.dart';
import 'data/database/settings_dao.dart';
import 'data/database/tempo_database.dart';
import 'features/launch/launch_screen.dart';
import 'platform/startup/startup_controller.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  await TempoLog.open();
  // Prepared before the window is shown, so it never appears opaque and then
  // turns translucent a frame later.
  await TempoWindowEffect.initialise();
  final bool hidden = arguments.contains(hiddenLaunchFlag);
  await configureWindow(startHidden: hidden);
  configureStartup();

  // The database is opened before the first frame so every screen can read it
  // without waiting, and so a failure to open it is known immediately: the app
  // still starts, and says so rather than showing an empty week.
  final TempoDatabase? database = await TempoDatabase.open();
  final Map<String, String> settings = database == null
      ? const <String, String>{}
      : await database.settings.all();

  // Opened at sign-in, before the first run has explained what is measured,
  // Tempo would sit in the tray recording nothing and unable to say why. It
  // shows itself instead; from the next sign-in on, it stays in the tray.
  final bool stayHidden =
      hidden && settings[SettingsKeys.onboardingCompleted] == 'true';
  if (stayHidden) {
    // Nobody is watching an opening that happens off screen, so the app is
    // handed over already finished.
    launchDone.value = true;
    launchReveal.value = 1;
  } else if (hidden) {
    await revealWindow();
  }

  // Applied on the way in rather than in the background: history the person
  // asked not to keep should not outlive the launch that noticed.
  await _applyRetention(database, settings);

  // Repaired here rather than at the toggle, because the thing that breaks it
  // — Tempo being moved, or never registered at all — happens while Tempo is
  // not running to see it.
  await ensureStartupRegistered(database: database, settings: settings);

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
