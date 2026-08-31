import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import '../../core/diagnostics/tempo_log.dart';
import '../../core/constants/app_info.dart';
import '../../core/platform/tempo_platform.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../data/database/settings_dao.dart';
import '../../data/database/tempo_database.dart';
import 'windows_startup.dart';

/// Passed by the system when Tempo is opened at login.
const String hiddenLaunchFlag = '--hidden';

/// Registers Tempo with the system's own startup mechanism — the Run key on
/// Windows, a login item on macOS. Nothing is written by hand: the platform is
/// asked to do it.
void configureStartup() {
  if (!TempoPlatform.isDesktop) {
    return;
  }
  launchAtStartup.setup(
    appName: AppInfo.name,
    appPath: _appPath,
    // Started by the system rather than by hand, Tempo opens straight into the
    // tray and begins measuring instead of taking over the screen.
    args: const <String>[hiddenLaunchFlag],
  );
}

/// Where the system is told to find Tempo.
///
/// Windows keeps the whole command in a single string, so a copy living
/// somewhere with a space in the path — `C:\Program Files\Tempo` — has to
/// arrive quoted, or the system reads the first word as the program and starts
/// nothing. macOS is handed the path itself and would take the quotes
/// literally, so they are added only where they mean something.
String get _appPath {
  final String path = Platform.resolvedExecutable;
  return TempoPlatform.isWindows && path.contains(' ') ? '"$path"' : path;
}

/// The command the system should be holding for Tempo, written exactly as
/// `launch_at_startup` writes it so the two can be compared.
String get _startupCommand => '$_appPath $hiddenLaunchFlag';

/// Makes sure Tempo really will open at the next sign-in.
///
/// Called once per launch, as soon as the stored settings are known:
///
///  * **The first run turns it on.** Tempo cannot measure a session it was not
///    running for, so a screen-time tracker that waits to be switched on is
///    one that has already missed the morning. It asks to be started rather
///    than waiting to be found in Settings.
///  * **A move is repaired.** The system's entry holds a path. Put Tempo
///    somewhere else and that path is left pointing at nothing, which fails in
///    the worst way available: nothing starts, and nothing says why. The
///    registered command is compared against this copy's own and rewritten
///    when they differ.
///  * **A decision is left alone.** Turning it off in Settings is written down
///    here, and turning it off in the system's own startup list is read and
///    respected. Neither is quietly undone on the next launch.
Future<void> ensureStartupRegistered({
  required TempoDatabase? database,
  required Map<String, String> settings,
}) async {
  if (!TempoPlatform.isDesktop) {
    return;
  }
  final String? recorded = settings[SettingsKeys.launchAtStartup];
  if (recorded == 'false') {
    return;
  }
  try {
    if (await _isRegisteredCorrectly()) {
      // Nothing to do but write down, on the first run, that this is how Tempo
      // starts — so a later "off" has something to disagree with.
      if (recorded == null) {
        await database?.settings.set(SettingsKeys.launchAtStartup, 'true');
      }
      return;
    }
    await launchAtStartup.enable();
    await database?.settings.set(SettingsKeys.launchAtStartup, 'true');
    TempoLog.note('Tempo will open at sign-in · $_startupCommand');
  } on Object catch (error, stack) {
    TempoLog.error('could not register Tempo to open at sign-in', error, stack);
  }
}

/// Whether the system already holds the right entry for this copy of Tempo.
///
/// On Windows the two halves of the answer are read apart, so an entry someone
/// switched off in Task Manager is recognised as switched off rather than as
/// missing — and is then left exactly as they left it.
Future<bool> _isRegisteredCorrectly() async {
  if (!TempoPlatform.isWindows) {
    return launchAtStartup.isEnabled();
  }
  if (!WindowsStartupEntry.approved(AppInfo.name)) {
    TempoLog.note(
      'opening at sign-in is switched off for Tempo in the system startup '
      'list; left as it is',
    );
    return true;
  }
  return WindowsStartupEntry.command(AppInfo.name) == _startupCommand;
}

/// Whether Tempo opens when the computer does.
///
/// The system holds this setting, not Tempo, so it is read back from the
/// system rather than remembered separately — which also means turning it off
/// elsewhere is reflected here. What Tempo does store is the choice itself, so
/// that a deliberate "off" is not undone by the repair the next launch runs.
class StartupController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => _read();

  Future<void> set({required bool enabled}) async {
    if (!TempoPlatform.isDesktop) {
      return;
    }
    state = const AsyncValue<bool>.loading();
    try {
      if (enabled) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
      // Written down before the state is read back: the next launch honours
      // this choice instead of registering Tempo again the way a first run
      // does.
      final TempoDatabase? database = ref.read(databaseProvider);
      await database?.settings.set(SettingsKeys.launchAtStartup, '$enabled');
    } on Object catch (error, stack) {
      TempoLog.error('could not change the startup setting · $error');
      state = AsyncValue<bool>.error(error, stack);
      return;
    }
    state = AsyncValue<bool>.data(await _read());
  }

  Future<bool> _read() async {
    if (!TempoPlatform.isDesktop) {
      return false;
    }
    try {
      return await launchAtStartup.isEnabled();
    } on Object catch (error) {
      TempoLog.error('could not read the startup setting · $error');
      return false;
    }
  }
}

final AsyncNotifierProvider<StartupController, bool> startupProvider =
    AsyncNotifierProvider<StartupController, bool>(StartupController.new);
