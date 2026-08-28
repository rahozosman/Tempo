import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_info.dart';
import '../core/layout/tempo_scroll_behavior.dart';
import '../core/motion/tempo_motion.dart';
import '../core/theme/tempo_theme.dart';
import '../features/settings/appearance_controller.dart';
import '../features/shell/app_shell.dart';

/// The application root. Both theme variants are built from the same tokens,
/// and [TempoTheme] lerps between them, so switching appearance crossfades the
/// whole product instead of snapping.
class TempoApp extends ConsumerWidget {
  const TempoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppearanceState appearance = ref.watch(appearanceProvider);
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: TempoThemeData.light(accentIntensity: appearance.accentIntensity),
      darkTheme: TempoThemeData.dark(
        accentIntensity: appearance.accentIntensity,
      ),
      themeMode: appearance.themeMode,
      themeAnimationDuration: TempoDuration.slow,
      themeAnimationCurve: TempoCurve.gentle,
      scrollBehavior: const TempoScrollBehavior(),
      home: const AppShell(),
    );
  }
}
