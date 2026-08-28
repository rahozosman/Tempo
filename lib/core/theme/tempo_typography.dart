import 'package:flutter/material.dart';

import 'tempo_colors.dart';

/// Typography for Tempo.
///
/// Tempo ships no font binaries: it resolves the best available system display
/// face on each platform (Segoe UI Variable on Windows 11, SF Pro on macOS)
/// which keeps the app native-feeling and the bundle small.
class TempoTypography {
  const TempoTypography._();

  static const List<String> family = <String>[
    'Segoe UI Variable Display',
    'Segoe UI Variable Text',
    'Segoe UI',
    'SF Pro Display',
    '.AppleSystemUIFont',
    'Helvetica Neue',
    'Inter',
    'Roboto',
  ];

  /// Lining, fixed-width figures. Every statistic in Tempo uses these so
  /// counting numbers never jitter.
  static const List<FontFeature> numeric = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle _style(
    double size,
    FontWeight weight,
    double letterSpacing,
    double height,
  ) => TextStyle(
    fontFamilyFallback: family,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// The oversized statistic face, used for the hero screen-time figure.
  static TextStyle get hero => _style(64, FontWeight.w300, -2.0, 1.0);

  static TextTheme textTheme(TempoColors c) {
    final Color primary = c.textPrimary;
    final Color secondary = c.textSecondary;
    return TextTheme(
      displayLarge: _style(
        64,
        FontWeight.w300,
        -2.0,
        1.0,
      ).copyWith(color: primary, fontFeatures: numeric),
      displayMedium: _style(
        48,
        FontWeight.w300,
        -1.4,
        1.02,
      ).copyWith(color: primary, fontFeatures: numeric),
      displaySmall: _style(
        38,
        FontWeight.w400,
        -1.0,
        1.05,
      ).copyWith(color: primary, fontFeatures: numeric),
      headlineLarge: _style(
        32,
        FontWeight.w600,
        -0.8,
        1.12,
      ).copyWith(color: primary),
      headlineMedium: _style(
        24,
        FontWeight.w600,
        -0.5,
        1.18,
      ).copyWith(color: primary),
      headlineSmall: _style(
        20,
        FontWeight.w600,
        -0.3,
        1.22,
      ).copyWith(color: primary),
      titleLarge: _style(18, FontWeight.w600, -0.2, 1.25).copyWith(
        color: primary,
      ),
      titleMedium: _style(16, FontWeight.w600, -0.1, 1.3).copyWith(
        color: primary,
      ),
      titleSmall: _style(14, FontWeight.w600, 0.0, 1.35).copyWith(
        color: primary,
      ),
      bodyLarge: _style(15, FontWeight.w400, 0.0, 1.5).copyWith(color: primary),
      bodyMedium: _style(
        14,
        FontWeight.w400,
        0.0,
        1.5,
      ).copyWith(color: secondary),
      bodySmall: _style(
        13,
        FontWeight.w400,
        0.1,
        1.45,
      ).copyWith(color: secondary),
      labelLarge: _style(14, FontWeight.w500, 0.1, 1.2).copyWith(
        color: primary,
      ),
      labelMedium: _style(
        12.5,
        FontWeight.w500,
        0.2,
        1.2,
      ).copyWith(color: secondary),
      labelSmall: _style(
        11,
        FontWeight.w600,
        1.4,
        1.2,
      ).copyWith(color: c.textTertiary),
    );
  }
}
