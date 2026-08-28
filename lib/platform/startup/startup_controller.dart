import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import '../../core/diagnostics/tempo_log.dart';
import '../../core/constants/app_info.dart';
import '../../core/platform/tempo_platform.dart';

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
    appPath: Platform.resolvedExecutable,
    // Started by the system rather than by hand, Tempo opens straight into the
    // tray and begins measuring instead of taking over the screen.
    args: <String>[hiddenLaunchFlag],
  );
}

/// Whether Tempo opens when the computer does.
///
/// The system holds this setting, not Tempo, so it is read back from the
/// system rather than remembered separately — which also means turning it off
/// elsewhere is reflected here.
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
