import 'dart:math' as math;
import 'dart:ui' show Display;

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../core/constants/app_info.dart';
import '../core/platform/tempo_platform.dart';
import '../core/theme/tempo_colors.dart';
import '../core/theme/tempo_metrics.dart';

/// Prepares the desktop window before the first frame.
///
/// Tempo hides the system title bar and draws its own, so the window reads as
/// one continuous glass surface. macOS keeps its native window buttons; on
/// Windows the caption buttons come drawn by the Tempo title bar.
/// True when the window was opened straight into the tray at sign-in.
bool tempoLaunchedHidden = false;

Future<void> configureWindow({bool startHidden = false}) async {
  tempoLaunchedHidden = startHidden;
  if (!TempoPlatform.isDesktop) {
    return;
  }
  await windowManager.ensureInitialized();

  final WindowOptions options = WindowOptions(
    size: _openingSize(),
    minimumSize: TempoSizes.minWindow,
    center: true,
    title: AppInfo.name,
    // Shows for a fraction of a second before the first frame, and behind the
    // rounded window corners, so it matches the midnight backdrop.
    backgroundColor: TempoColors.dark.backdrop,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: TempoPlatform.isMacOS,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    if (startHidden) {
      // Opened at login: it measures from the tray until asked for.
      return;
    }
    await windowManager.show();
    await windowManager.focus();
  });
}

/// The size Tempo opens at, never bigger than the screen it opens on.
///
/// The design window is 1440x900. A scaled 1080p laptop has less room than
/// that, and a window taller than the screen gets centred with its title bar
/// above the top edge — out of reach. Fitting the display keeps the whole
/// window, and its own title bar, on screen.
Size _openingSize() {
  const Size preferred = TempoSizes.defaultWindow;
  final List<Display> displays = WidgetsBinding
      .instance
      .platformDispatcher
      .displays
      .toList();
  if (displays.isEmpty) {
    return preferred;
  }
  final Display display = displays.first;
  final Size screen = display.size / display.devicePixelRatio;
  // Room for the taskbar, and a little desk showing around the window.
  return Size(
    math.min(preferred.width, screen.width - 96),
    math.min(preferred.height, screen.height - 120),
  );
}
