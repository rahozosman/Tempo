import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'tempo_colors.dart';
import 'tempo_metrics.dart';
import 'tempo_typography.dart';

/// Every Tempo design token that varies between light and dark, carried on the
/// [ThemeData] so a theme change animates instead of snapping.
@immutable
class TempoTheme extends ThemeExtension<TempoTheme> {
  const TempoTheme({
    required this.colors,
    required this.accentIntensity,
    required this.isDark,
  });

  final TempoColors colors;

  /// How strongly accent glows read, 0.4 to 1.4. Exposed in Settings.
  final double accentIntensity;

  final bool isDark;

  LinearGradient get accentGradient => TempoGradients.accent(colors);
  LinearGradient get accentWideGradient => TempoGradients.accentWide(colors);
  LinearGradient get selectionGradient => TempoGradients.selection(colors);
  LinearGradient get sheenGradient => TempoGradients.sheen(colors);

  List<BoxShadow> get cardShadow => TempoShadows.soft(colors);
  List<BoxShadow> get panelShadow => TempoShadows.lifted(colors);

  List<BoxShadow> accentGlow([double multiplier = 1]) =>
      TempoShadows.glow(colors.accent, intensity: accentIntensity * multiplier);

  List<BoxShadow> glowOf(Color color, [double multiplier = 1]) =>
      TempoShadows.glow(color, intensity: accentIntensity * multiplier);

  @override
  TempoTheme copyWith({
    TempoColors? colors,
    double? accentIntensity,
    bool? isDark,
  }) => TempoTheme(
    colors: colors ?? this.colors,
    accentIntensity: accentIntensity ?? this.accentIntensity,
    isDark: isDark ?? this.isDark,
  );

  @override
  TempoTheme lerp(covariant TempoTheme? other, double t) {
    if (other == null) {
      return this;
    }
    return TempoTheme(
      colors: TempoColors.lerp(colors, other.colors, t),
      accentIntensity:
          lerpDouble(accentIntensity, other.accentIntensity, t) ??
          accentIntensity,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Builds the two [ThemeData] variants Tempo ships.
class TempoThemeData {
  const TempoThemeData._();

  static ThemeData dark({double accentIntensity = 1}) =>
      _build(Brightness.dark, TempoColors.dark, accentIntensity);

  static ThemeData light({double accentIntensity = 1}) =>
      _build(Brightness.light, TempoColors.light, accentIntensity);

  static ThemeData _build(
    Brightness brightness,
    TempoColors c,
    double accentIntensity,
  ) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: isDark ? const Color(0xFF05081A) : const Color(0xFFFFFFFF),
      secondary: c.accentAlt,
      onSecondary: const Color(0xFFFFFFFF),
      error: c.danger,
      onError: const Color(0xFFFFFFFF),
      surface: c.surface,
      onSurface: c.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      dividerColor: c.border,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      textTheme: TempoTypography.textTheme(c),
      iconTheme: IconThemeData(color: c.textSecondary, size: 20),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.28),
        selectionHandleColor: c.accent,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 420),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: c.surfaceElevated.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(TempoRadius.sm),
          border: Border.all(color: c.border),
          boxShadow: TempoShadows.soft(c),
        ),
        textStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamilyFallback: TempoTypography.family,
        ),
      ),
      // A Mac overlay scrollbar: a thin capsule that fades in while the page
      // moves, thickens and shows its track when the pointer comes near, and
      // fades away again on its own.
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.resolveWith<double>(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.dragged)
              ? 10
              : 5,
        ),
        radius: const Radius.circular(6),
        crossAxisMargin: 4,
        mainAxisMargin: 10,
        interactive: true,
        thumbVisibility: const WidgetStatePropertyAll<bool>(false),
        trackVisibility: WidgetStateProperty.resolveWith<bool>(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged),
        ),
        trackColor: WidgetStatePropertyAll<Color>(c.glassFill),
        trackBorderColor: const WidgetStatePropertyAll<Color>(
          Color(0x00000000),
        ),
        thumbColor: WidgetStateProperty.resolveWith<Color>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.dragged)) {
            return c.textSecondary.withValues(alpha: 0.72);
          }
          if (states.contains(WidgetState.hovered)) {
            return c.textSecondary.withValues(alpha: 0.55);
          }
          return c.textSecondary.withValues(alpha: 0.28);
        }),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: c.accent,
        inactiveTrackColor: c.border,
        thumbColor: c.textPrimary,
        overlayColor: c.accent.withValues(alpha: 0.14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      extensions: <ThemeExtension<dynamic>>[
        TempoTheme(colors: c, accentIntensity: accentIntensity, isDark: isDark),
      ],
    );
  }
}

/// Terse access to the design system from any widget.
extension TempoThemeAccess on BuildContext {
  TempoTheme get tempo =>
      Theme.of(this).extension<TempoTheme>() ??
      const TempoTheme(
        colors: TempoColors.dark,
        accentIntensity: 1,
        isDark: true,
      );

  TempoColors get colors => tempo.colors;

  TextTheme get typo => Theme.of(this).textTheme;
}
