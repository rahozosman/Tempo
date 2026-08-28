import 'package:flutter/material.dart';

/// Semantic colour slots for Tempo.
///
/// UI code never hard-codes a colour: it reads these through `context.colors`
/// so the midnight and daylight identities stay perfectly in sync.
@immutable
class TempoColors {
  const TempoColors({
    required this.backdrop,
    required this.backdropEdge,
    required this.surface,
    required this.surfaceElevated,
    required this.glassFill,
    required this.glassFillStrong,
    required this.glassSheen,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.accentAlt,
    required this.accentSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.positive,
    required this.warning,
    required this.danger,
    required this.shadow,
    required this.scrim,
  });

  /// Page background base.
  final Color backdrop;

  /// Outer edge of the background gradient and vignette.
  final Color backdropEdge;

  /// Opaque panel base (menus, tooltips).
  final Color surface;

  /// Raised opaque surface.
  final Color surfaceElevated;

  /// Translucent glass fill.
  final Color glassFill;

  /// Translucent glass fill for hovered or emphasised surfaces.
  final Color glassFillStrong;

  /// Top-edge sheen painted over glass.
  final Color glassSheen;

  /// Hairline border.
  final Color border;

  /// Hairline border for hovered or focused surfaces.
  final Color borderStrong;

  /// Electric blue, the primary accent.
  final Color accent;

  /// Royal purple, the secondary accent.
  final Color accentAlt;

  /// Soft violet, the highlight accent.
  final Color accentSoft;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color positive;
  final Color warning;
  final Color danger;

  /// Base colour used to build shadows.
  final Color shadow;

  /// Overlay behind modal content.
  final Color scrim;

  /// Midnight, the primary identity.
  static const TempoColors dark = TempoColors(
    backdrop: Color(0xFF080A18),
    backdropEdge: Color(0xFF04050E),
    surface: Color(0xFF0E1024),
    surfaceElevated: Color(0xFF161936),
    glassFill: Color(0x0FFFFFFF),
    glassFillStrong: Color(0x1FFFFFFF),
    glassSheen: Color(0x24FFFFFF),
    border: Color(0x16FFFFFF),
    borderStrong: Color(0x33FFFFFF),
    accent: Color(0xFF4C8DFF),
    accentAlt: Color(0xFF8B5CFF),
    accentSoft: Color(0xFFB06CFF),
    textPrimary: Color(0xFFF7F7FF),
    textSecondary: Color(0xFF9A9CB5),
    textTertiary: Color(0xFF6A6C86),
    positive: Color(0xFF4ADE9E),
    warning: Color(0xFFFFC46B),
    danger: Color(0xFFFF7A93),
    shadow: Color(0xFF01020A),
    scrim: Color(0xCC05060F),
  );

  /// Daylight, the same identity under a light surface.
  static const TempoColors light = TempoColors(
    backdrop: Color(0xFFF4F5FC),
    backdropEdge: Color(0xFFE3E6F6),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    glassFill: Color(0xB8FFFFFF),
    glassFillStrong: Color(0xE6FFFFFF),
    glassSheen: Color(0xCCFFFFFF),
    border: Color(0x1A1A2050),
    borderStrong: Color(0x331A2050),
    accent: Color(0xFF3B6FE0),
    accentAlt: Color(0xFF7A45E6),
    accentSoft: Color(0xFF9A55F0),
    textPrimary: Color(0xFF11132A),
    textSecondary: Color(0xFF5A5D7B),
    textTertiary: Color(0xFF8A8DA6),
    positive: Color(0xFF12A97B),
    warning: Color(0xFFC97F1B),
    danger: Color(0xFFDD4B66),
    shadow: Color(0xFF8A90B4),
    scrim: Color(0xCCF4F5FC),
  );

  static TempoColors lerp(TempoColors a, TempoColors b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return TempoColors(
      backdrop: Color.lerp(a.backdrop, b.backdrop, t)!,
      backdropEdge: Color.lerp(a.backdropEdge, b.backdropEdge, t)!,
      surface: Color.lerp(a.surface, b.surface, t)!,
      surfaceElevated: Color.lerp(a.surfaceElevated, b.surfaceElevated, t)!,
      glassFill: Color.lerp(a.glassFill, b.glassFill, t)!,
      glassFillStrong: Color.lerp(a.glassFillStrong, b.glassFillStrong, t)!,
      glassSheen: Color.lerp(a.glassSheen, b.glassSheen, t)!,
      border: Color.lerp(a.border, b.border, t)!,
      borderStrong: Color.lerp(a.borderStrong, b.borderStrong, t)!,
      accent: Color.lerp(a.accent, b.accent, t)!,
      accentAlt: Color.lerp(a.accentAlt, b.accentAlt, t)!,
      accentSoft: Color.lerp(a.accentSoft, b.accentSoft, t)!,
      textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
      textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
      textTertiary: Color.lerp(a.textTertiary, b.textTertiary, t)!,
      positive: Color.lerp(a.positive, b.positive, t)!,
      warning: Color.lerp(a.warning, b.warning, t)!,
      danger: Color.lerp(a.danger, b.danger, t)!,
      shadow: Color.lerp(a.shadow, b.shadow, t)!,
      scrim: Color.lerp(a.scrim, b.scrim, t)!,
    );
  }
}

/// The only gradients used in the product, applied sparingly.
class TempoGradients {
  const TempoGradients._();

  static LinearGradient accent(TempoColors c) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[c.accent, c.accentAlt],
  );

  static LinearGradient accentWide(TempoColors c) => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[c.accent, c.accentAlt, c.accentSoft],
  );

  static LinearGradient selection(TempoColors c) => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[
      c.accent.withValues(alpha: 0.26),
      c.accentAlt.withValues(alpha: 0.14),
    ],
  );

  static LinearGradient glass(Color fill) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[fill, fill.withValues(alpha: fill.a * 0.55)],
  );

  static LinearGradient sheen(TempoColors c) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      c.glassSheen.withValues(alpha: c.glassSheen.a * 0.55),
      c.glassSheen.withValues(alpha: 0),
    ],
    stops: const <double>[0.0, 0.6],
  );
}

/// Depth. Soft, wide and low contrast, never a hard drop shadow.
class TempoShadows {
  const TempoShadows._();

  static List<BoxShadow> soft(TempoColors c) => <BoxShadow>[
    BoxShadow(
      color: c.shadow.withValues(alpha: 0.30),
      blurRadius: 28,
      spreadRadius: -12,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> lifted(TempoColors c) => <BoxShadow>[
    BoxShadow(
      color: c.shadow.withValues(alpha: 0.42),
      blurRadius: 48,
      spreadRadius: -14,
      offset: const Offset(0, 24),
    ),
  ];

  static List<BoxShadow> glow(Color color, {double intensity = 1}) =>
      <BoxShadow>[
        BoxShadow(
          color: color.withValues(alpha: (0.26 * intensity).clamp(0.0, 1.0)),
          blurRadius: 28,
          spreadRadius: -6,
        ),
      ];
}
