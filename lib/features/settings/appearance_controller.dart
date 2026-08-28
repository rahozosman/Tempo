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
    this.elementScale = 1.0,
    this.glass = 1.0,
  });

  final ThemeMode themeMode;

  /// Multiplies every accent glow, 0.4 (quiet) to 1.4 (vivid).
  final double accentIntensity;

  /// How large text, icons and controls are drawn. The layout itself is not
  /// scaled: a larger setting makes pages longer, not narrower.
  final double elementScale;

  /// How much glass the surfaces carry: 0.4 is nearly clear, 1.6 is
  /// frosted and near opaque.
  final double glass;

  static const double minGlass = 0.4;
  static const double maxGlass = 1.6;

  static const double minScale = 0.85;
  static const double maxScale = 1.4;
  static const double scaleStep = 0.05;

  AppearanceState copyWith({
    ThemeMode? themeMode,
    double? accentIntensity,
    double? elementScale,
    double? glass,
  }) => AppearanceState(
    themeMode: themeMode ?? this.themeMode,
    accentIntensity: accentIntensity ?? this.accentIntensity,
    elementScale: elementScale ?? this.elementScale,
    glass: glass ?? this.glass,
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
      elementScale:
          (double.tryParse(stored[SettingsKeys.elementScale] ?? '') ?? 1.0)
              .clamp(AppearanceState.minScale, AppearanceState.maxScale),
      glass: (double.tryParse(stored[SettingsKeys.glass] ?? '') ?? 1.0).clamp(
        AppearanceState.minGlass,
        AppearanceState.maxGlass,
      ),
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

  void setGlass(double value) {
    final double glass = value.clamp(
      AppearanceState.minGlass,
      AppearanceState.maxGlass,
    );
    state = state.copyWith(glass: glass);
    _remember(SettingsKeys.glass, glass.toStringAsFixed(2));
  }

  /// Sets the element size, snapped to the step both the slider and the
  /// keyboard move in.
  void setElementScale(double value) {
    final double snapped =
        (value.clamp(AppearanceState.minScale, AppearanceState.maxScale) /
                AppearanceState.scaleStep)
            .roundToDouble() *
        AppearanceState.scaleStep;
    state = state.copyWith(elementScale: snapped);
    _remember(SettingsKeys.elementScale, snapped.toStringAsFixed(2));
  }

  void largerElements() =>
      setElementScale(state.elementScale + AppearanceState.scaleStep);

  void smallerElements() =>
      setElementScale(state.elementScale - AppearanceState.scaleStep);

  void resetElementScale() => setElementScale(1);

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
