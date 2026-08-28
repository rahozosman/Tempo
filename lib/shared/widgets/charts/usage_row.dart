import 'package:flutter/material.dart';

import '../../../core/motion/tempo_animations.dart';
import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_palette.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/theme/tempo_typography.dart';
import '../../../core/utilities/tempo_format.dart';
import '../../../domain/analytics/app_usage.dart';
import '../app_glyph.dart';
import 'share_bar.dart';

/// One application in a ranked list: mark, name, time, a bar for its share of
/// the period, and its trend against the same period before.
///
/// The bar grows once when the row appears and is the same component on Home,
/// Today and the Applications screen.
class UsageRow extends StatelessWidget {
  const UsageRow({
    super.key,
    required this.usage,
    required this.total,
    this.index = 0,
    this.onTap,
    this.showTrend = true,
  });

  final AppUsage usage;

  /// The whole the share is measured against.
  final Duration total;

  /// Position in the list, used to stagger the entrance.
  final int index;

  final VoidCallback? onTap;
  final bool showTrend;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final double share = usage.shareOf(total);
    final Color tone = TempoPalette.toneFor(c, usage.id);
    final double? change = usage.change;

    return TempoEntrance(
      index: index,
      rise: 10,
      child: HoverBuilder(
        onTap: onTap,
        builder: (BuildContext context, bool hovered) => AnimatedContainer(
          duration: TempoMotion.of(context, TempoDuration.base),
          curve: TempoCurve.gentle,
          padding: const EdgeInsets.symmetric(
            horizontal: TempoSpace.sm,
            vertical: TempoSpace.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TempoRadius.md),
            color: hovered && onTap != null
                ? c.glassFill
                : Colors.transparent,
          ),
          child: Row(
            children: <Widget>[
              AppGlyph(id: usage.id, name: usage.name),
              const SizedBox(width: TempoSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            usage.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typo.titleSmall,
                          ),
                        ),
                        const SizedBox(width: TempoSpace.sm),
                        Text(
                          TempoFormat.hm(usage.duration),
                          style: context.typo.labelLarge?.copyWith(
                            color: c.textSecondary,
                            fontFeatures: TempoTypography.numeric,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TempoSpace.xs + 1),
                    ShareBar(share: share, tone: tone, hovered: hovered),
                  ],
                ),
              ),
              const SizedBox(width: TempoSpace.md),
              SizedBox(
                width: 58,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      TempoFormat.percent(share),
                      style: context.typo.labelLarge?.copyWith(
                        color: c.textPrimary,
                        fontFeatures: TempoTypography.numeric,
                      ),
                    ),
                    if (showTrend && change != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        TempoFormat.signedPercent(change),
                        style: context.typo.bodySmall?.copyWith(
                          fontSize: 11.5,
                          color: change >= 0 ? c.accentSoft : c.accent,
                          fontFeatures: TempoTypography.numeric,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
