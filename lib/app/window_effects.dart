import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:window_manager/window_manager.dart';

import '../core/diagnostics/tempo_log.dart';
import '../core/platform/tempo_platform.dart';
import '../core/theme/tempo_colors.dart';

/// The window's own material.
///
/// Tempo paints glass of its own, but only the system can blur what is
/// *behind* the window. On macOS that is `NSVisualEffectView`; on Windows 11 it
/// is Mica. Both make the app sit in the desktop rather than on top of it.
///
/// Everything here degrades quietly: a system that cannot do it keeps the
/// opaque window, and the interface is drawn to look right either way.
class TempoWindowEffect {
  const TempoWindowEffect._();

  static bool _initialised = false;

  /// Whether the running system can blur behind the window at all.
  ///
  /// Mica needs Windows 11 (build 22000); older Windows keeps its solid
  /// window rather than the acrylic that stutters when a window is dragged.
  static bool get isSupported {
    if (TempoPlatform.isMacOS) {
      return true;
    }
    if (!TempoPlatform.isWindows) {
      return false;
    }
    return _windowsBuild >= 22000;
  }

  /// True once an effect is actually in place, which is what tells the
  /// interface to let the desktop show through.
  static bool get isActive => _active;
  static bool _active = false;

  static Future<void> initialise() async {
    if (_initialised || !isSupported) {
      return;
    }
    try {
      await Window.initialize();
      _initialised = true;
    } on Object catch (error) {
      TempoLog.error('window effects unavailable', error);
    }
  }

  /// Applies the material, or removes it. [dark] keeps Mica on the right side
  /// of the system's own light and dark treatment.
  static Future<void> apply({
    required bool enabled,
    required bool dark,
  }) async {
    if (!isSupported) {
      _active = false;
      return;
    }
    await initialise();
    if (!_initialised) {
      _active = false;
      return;
    }
    try {
      if (!enabled) {
        await Window.setEffect(effect: WindowEffect.disabled, dark: dark);
        // Back to a solid window: without this the frame would keep whatever
        // the material left behind it.
        await windowManager.setBackgroundColor(
          dark ? TempoColors.dark.backdrop : TempoColors.light.backdrop,
        );
        _active = false;
        return;
      }
      // The window itself must stop painting, or there is nothing for the
      // system material to show through.
      await windowManager.setBackgroundColor(Colors.transparent);
      await Window.setEffect(
        // The sidebar material is the quiet one: it carries the desktop
        // without competing with what Tempo draws on top of it.
        effect: TempoPlatform.isMacOS
            ? WindowEffect.sidebar
            : WindowEffect.mica,
        dark: dark,
      );
      _active = true;
    } on Object catch (error) {
      TempoLog.error('the window material could not be set', error);
      _active = false;
    }
  }

  static int get _windowsBuild {
    // "10.0 (Build 22631)" — the build number is what separates 10 from 11.
    final RegExp pattern = RegExp(r'(\d{5,})');
    final Match? match = pattern.firstMatch(Platform.operatingSystemVersion);
    return match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
  }
}

/// Whether the window is currently letting the desktop through.
///
/// Held as a notifier so the shell can soften its own background the moment
/// the material is applied, without rebuilding the whole app.
final ValueNotifier<bool> windowEffectActive = ValueNotifier<bool>(false);
