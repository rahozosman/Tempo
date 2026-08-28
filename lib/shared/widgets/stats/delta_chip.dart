import 'package:flutter/material.dart';

import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/utilities/tempo_format.dart';
import '../glass/glass_card.dart';
import '../tempo_icon.dart';

/// A comparison against an earlier period.
///
/// More time is not treated as failure and less time is not treated as
/// success: both directions use the product accents, and only the arrow says
/// which way it went.
class DeltaChip extends StatelessWidget {
  const DeltaChip({
    super.key,
    required this.change,
    required this.caption,
    this.compact = false,
  });

  /// Relative change, where 0.18 is eighteen percent more. Null means there is
  /// nothing to compare with yet.
  final double? change;

  final String caption;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final double? value = change;
    final bool rising = (value ?? 0) >= 0;
    final Color tone = value == null
        ? c.textTertiary
        : (rising ? c.accentSoft : c.accent);
    final TextStyle? label = compact
        ? context.typo.labelMedium
        : context.typo.labelLarge;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? TempoSpace.xs + 2 : TempoSpace.sm,
        vertical: compact ? TempoSpace.xxs : TempoSpace.xxs + 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TempoRadius.sm),
        color: value == null ? c.glassFill : tone.withValues(alpha: 0.12),
        border: Border.all(
          color: value == null ? c.border : tone.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (value != null) ...<Widget>[
            // Hovering the card the chip sits in nudges the arrow the way it
            // points, a beat of life on an otherwise still figure.
            AnimatedSlide(
              offset: Offset(
                0,
                CardHoverScope.hoveredOf(context) ? (rising ? -0.16 : 0.16) : 0,
              ),
              duration: TempoMotion.of(context, TempoDuration.base),
              curve: TempoCurve.gentle,
              child: TempoIcon(
                rising ? TempoGlyph.trendUp : TempoGlyph.trendDown,
                size: compact ? 13 : 15,
                strokeWidth: 2,
                color: tone,
              ),
            ),
            const SizedBox(width: TempoSpace.xxs + 1),
            Text(
              TempoFormat.signedPercent(value),
              style: label?.copyWith(color: c.textPrimary),
            ),
            if (caption.isNotEmpty) const SizedBox(width: TempoSpace.xxs + 1),
          ],
          if (value == null || caption.isNotEmpty)
            Text(
              value == null
                  ? (caption.isEmpty ? 'New' : 'No comparison yet')
                  : caption,
              style: label?.copyWith(color: c.textSecondary),
            ),
        ],
      ),
    );
  }
}
