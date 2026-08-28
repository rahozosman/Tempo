import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/tempo_theme.dart';
import '../features/settings/preferences_controller.dart';
import 'window_effects.dart';

/// Keeps the window's own material in step with the app.
///
/// It draws nothing. It watches two things — whether the preference is on, and
/// whether the app is currently dark — and re-applies the material when either
/// changes, because Mica has a light and a dark treatment of its own and a
/// window that disagrees with its contents looks broken.
class WindowMaterialSync extends ConsumerStatefulWidget {
  const WindowMaterialSync({super.key});

  @override
  ConsumerState<WindowMaterialSync> createState() => _WindowMaterialSyncState();
}

class _WindowMaterialSyncState extends ConsumerState<WindowMaterialSync> {
  bool? _enabled;
  bool? _dark;

  @override
  Widget build(BuildContext context) {
    final bool enabled = ref.watch(
      preferencesProvider.select(
        (TempoPreferences value) => value.windowBlur,
      ),
    );
    final bool dark = context.tempo.isDark;

    if (enabled != _enabled || dark != _dark) {
      _enabled = enabled;
      _dark = dark;
      unawaited(_apply(enabled: enabled, dark: dark));
    }
    return const SizedBox.shrink();
  }

  Future<void> _apply({required bool enabled, required bool dark}) async {
    await TempoWindowEffect.apply(enabled: enabled, dark: dark);
    if (mounted) {
      windowEffectActive.value = TempoWindowEffect.isActive;
    }
  }
}
