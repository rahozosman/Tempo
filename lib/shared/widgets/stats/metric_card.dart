import 'package:flutter/material.dart';

import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';
import '../glass/glass_card.dart';
import '../tempo_icon.dart';

/// One statistic: a quiet label, the figure, and a line of context.
///
/// Cards are meant to sit in a stretched row, so they all agree on padding and
/// rhythm and end up the same height.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.glyph,
    this.tone,
    this.onTap,
    this.footer,
  });

  final String label;

  /// Usually an [AnimatedDuration] or [AnimatedCount].
  final Widget value;

  final String? caption;
  final TempoGlyph? glyph;

  /// Accent for the glyph tile. Defaults to the product accent.
  final Color? tone;

  final VoidCallback? onTap;

  /// Optional widget below the caption, such as a split bar.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final Color resolved = tone ?? c.accent;

    return GlassCard(
      onTap: onTap,
      semanticLabel: label,
      padding: const EdgeInsets.all(TempoSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (glyph != null) ...<Widget>[
                // The tile lights with the card it sits in, so the hover
                // reads as one movement instead of two.
                Builder(
                  builder: (BuildContext context) {
                    final bool lit = CardHoverScope.hoveredOf(context);
                    return AnimatedContainer(
                      duration: TempoMotion.of(context, TempoDuration.base),
                      curve: TempoCurve.gentle,
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(TempoRadius.xs),
                        color: resolved.withValues(alpha: lit ? 0.24 : 0.14),
                        border: Border.all(
                          color: resolved.withValues(alpha: lit ? 0.44 : 0.24),
                        ),
                        boxShadow: lit
                            ? context.tempo.glowOf(resolved, 0.45)
                            : null,
                      ),
                      child: Center(
                        child: TempoIcon(
                          glyph!,
                          size: 14,
                          strokeWidth: 1.9,
                          color: resolved,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: TempoSpace.xs + 2),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: context.typo.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.md),
          value,
          if (caption != null) ...<Widget>[
            const SizedBox(height: TempoSpace.xxs + 2),
            Text(
              caption!,
              style: context.typo.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (footer != null) ...<Widget>[
            const SizedBox(height: TempoSpace.md),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// A thin two-tone bar showing how a whole splits in two, used under the
/// screen-time card to show active against idle.
class SplitBar extends StatelessWidget {
  const SplitBar({
    super.key,
    required this.fraction,
    this.leading,
    this.trailing,
    this.height = 6,
  });

  /// Share taken by the leading tone, 0 to 1.
  final double fraction;

  final Color? leading;
  final Color? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(
              color: trailing ?? c.textTertiary.withValues(alpha: 0.30),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: fraction.clamp(0.0, 1.0)),
              duration: TempoMotion.of(context, TempoDuration.slow),
              curve: TempoCurve.entrance,
              builder: (BuildContext context, double value, Widget? child) =>
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: child,
                  ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: leading,
                  gradient: leading == null
                      ? context.tempo.accentGradient
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
