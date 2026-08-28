import 'package:flutter/material.dart';

import '../../../core/motion/tempo_animations.dart';
import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';
import '../tempo_icon.dart';

enum GlassButtonStyle {
  /// Gradient accent. One per screen at most.
  primary,

  /// Glass with a hairline border. The default action.
  ghost,

  /// No chrome until hovered. Toolbars and inline actions.
  quiet,

  /// Destructive. Used only where something is actually removed.
  danger,
}

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    this.glyph,
    this.onPressed,
    this.style = GlassButtonStyle.ghost,
    this.compact = false,
  });

  final String label;
  final TempoGlyph? glyph;
  final VoidCallback? onPressed;
  final GlassButtonStyle style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final TempoTheme theme = context.tempo;
    final bool enabled = onPressed != null;
    final double height = context.sized(compact ? 34 : 42);

    return FocusRing(
      radius: height / 2,
      enabled: enabled,
      onActivate: onPressed,
      child: HoverBuilder(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        builder: (BuildContext context, bool hovered) {
          final bool active = hovered && enabled;
          final Color foreground = switch (style) {
            GlassButtonStyle.primary =>
              theme.isDark ? const Color(0xFF07091C) : const Color(0xFFFFFFFF),
            GlassButtonStyle.ghost => c.textPrimary,
            GlassButtonStyle.quiet => active ? c.textPrimary : c.textSecondary,
            GlassButtonStyle.danger => c.danger,
          };

          final BoxDecoration decoration = switch (style) {
            GlassButtonStyle.primary => BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: theme.accentGradient,
              boxShadow: active
                  ? theme.accentGlow(1.1)
                  : theme.accentGlow(0.55),
            ),
            GlassButtonStyle.ghost => BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              color: active ? c.glassFillStrong : c.glassFill,
              border: Border.all(color: active ? c.borderStrong : c.border),
            ),
            GlassButtonStyle.quiet => BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              color: active ? c.glassFill : Colors.transparent,
            ),
            GlassButtonStyle.danger => BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              color: c.danger.withValues(alpha: active ? 0.20 : 0.12),
              border: Border.all(
                color: c.danger.withValues(alpha: active ? 0.55 : 0.34),
              ),
            ),
          };

          return Opacity(
            opacity: enabled ? 1 : 0.45,
            child: PressableScale(
              onTap: onPressed,
              child: AnimatedContainer(
                duration: TempoMotion.of(context, TempoDuration.base),
                curve: TempoCurve.gentle,
                height: height,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? TempoSpace.sm : TempoSpace.md + 2,
                ),
                decoration: decoration,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (glyph != null) ...<Widget>[
                      TempoIcon(
                        glyph!,
                        size: compact ? 15 : 17,
                        color: foreground,
                      ),
                      const SizedBox(width: TempoSpace.xs),
                    ],
                    Text(
                      label,
                      style:
                          (compact
                                  ? context.typo.labelMedium
                                  : context.typo.labelLarge)
                              ?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A square, icon-only action. Used in the title bar and card headers.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    this.onPressed,
    this.size = 34,
    this.selected = false,
  });

  final TempoGlyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final double size = context.sized(this.size);
    return Tooltip(
      message: tooltip,
      child: FocusRing(
        radius: TempoRadius.sm,
        enabled: onPressed != null,
        onActivate: onPressed,
        child: HoverBuilder(
          cursor: onPressed != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          builder: (BuildContext context, bool hovered) {
            final bool active = hovered && onPressed != null;
            return PressableScale(
              onTap: onPressed,
              child: AnimatedContainer(
                duration: TempoMotion.of(context, TempoDuration.base),
                curve: TempoCurve.gentle,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(TempoRadius.sm),
                  color: selected
                      ? c.accent.withValues(alpha: 0.18)
                      : (active ? c.glassFill : Colors.transparent),
                  border: Border.all(
                    color: selected
                        ? c.accent.withValues(alpha: 0.34)
                        : (active ? c.border : Colors.transparent),
                  ),
                ),
                child: Center(
                  child: TempoIcon(
                    glyph,
                    size: size * 0.52,
                    color: selected
                        ? c.accent
                        : (active ? c.textPrimary : c.textSecondary),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
