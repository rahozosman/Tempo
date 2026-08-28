import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/analytics/analytics_providers.dart';
import '../../data/database/settings_dao.dart';
import '../../data/database/tempo_database.dart';

/// Appearance preferences. Tempo is dark by default because the midnight
/// identity is the product; daylight is a first-class alternative.
@immutable
class AppearanceState {
  const AppearanceState({
    this.themeMode = ThemeMode.dark,
    this.accentIntensity = 1.0,
  });

  final ThemeMode themeMode;

  /// Multiplies every accent glow, 0.4 (quiet) to 1.4 (vivid).
  final double accentIntensity;

  AppearanceState copyWith({ThemeMode? themeMode, double? accentIntensity}) =>
      AppearanceState(
        themeMode: themeMode ?? this.themeMode,
        accentIntensity: accentIntensity ?? this.accentIntensity,
      );
}

class AppearanceController extends Notifier<AppearanceState> {
  @override
  AppearanceState build() {
    final Map<String, String> stored = ref.read(storedSettingsProvider);
    return AppearanceState(
      themeMode: _modeFrom(stored[SettingsKeys.themeMode]),
      accentIntensity:
          (double.tryParse(stored[SettingsKeys.accentIntensity] ?? '') ?? 1.0)
              .clamp(0.4, 1.4),
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _remember(SettingsKeys.themeMode, mode.name);
  }

  void setAccentIntensity(double value) {
    final double intensity = value.clamp(0.4, 1.4);
    state = state.copyWith(accentIntensity: intensity);
    _remember(SettingsKeys.accentIntensity, intensity.toStringAsFixed(2));
  }

  /// Storing a preference never holds up the interface, and a database that
  /// could not be opened simply forgets the choice.
  void _remember(String key, String value) {
    final TempoDatabase? database = ref.read(databaseProvider);
    if (database != null) {
      unawaited(database.settings.set(key, value));
    }
  }

  static ThemeMode _modeFrom(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
}

final NotifierProvider<AppearanceController, AppearanceState>
appearanceProvider =
    NotifierProvider<AppearanceController, AppearanceState>(
      AppearanceController.new,
    );
