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
import '../../../shared/widgets/app_glyph.dart';
import '../../../shared/widgets/charts/share_bar.dart';
import '../../../shared/widgets/glass/glass_card.dart';
import '../../../shared/widgets/stats/delta_chip.dart';
import '../../../shared/widgets/tempo_icon.dart';

/// One application in the ranked list: its place, its mark, its identity, the
/// time it took, its share of the period and how that compares.
class ApplicationCard extends StatelessWidget {
  const ApplicationCard({
    super.key,
    required this.rank,
    required this.usage,
    required this.total,
    required this.onTap,
    this.index = 0,
  });

  final int rank;
  final AppUsage usage;
  final Duration total;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final double share = usage.shareOf(total);
    final Color tone = TempoPalette.toneFor(c, usage.id);

    return TempoEntrance(
      index: index,
      rise: 12,
      child: GlassCard(
        onTap: onTap,
        semanticLabel:
            '${usage.name}, ${TempoFormat.hmSpoken(usage.duration)}, '
            '${TempoFormat.percent(share)} of the period',
        padding: const EdgeInsets.symmetric(
          horizontal: TempoSpace.lg,
          vertical: TempoSpace.md + 2,
        ),
        child: HoverBuilder(
          cursor: SystemMouseCursors.click,
          builder: (BuildContext context, bool hovered) => Row(
            children: <Widget>[
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  style: context.typo.labelSmall?.copyWith(
                    fontFeatures: TempoTypography.numeric,
                    letterSpacing: 0,
                    fontSize: 13,
                  ),
                ),
              ),
              AppGlyph(id: usage.id, name: usage.name, size: 46),
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
                            style: context.typo.titleMedium,
                          ),
                        ),
                        const SizedBox(width: TempoSpace.sm),
                        Text(
                          TempoFormat.hm(usage.duration),
                          style: context.typo.titleMedium?.copyWith(
                            fontFeatures: TempoTypography.numeric,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      usage.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typo.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: c.textTertiary,
                      ),
                    ),
                    const SizedBox(height: TempoSpace.sm),
                    ShareBar(share: share, tone: tone, hovered: hovered),
                  ],
                ),
              ),
              const SizedBox(width: TempoSpace.lg),
              SizedBox(
                width: 86,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      TempoFormat.percent(share),
                      style: context.typo.titleSmall?.copyWith(
                        fontFeatures: TempoTypography.numeric,
                      ),
                    ),
                    const SizedBox(height: TempoSpace.xxs + 1),
                    DeltaChip(change: usage.change, caption: '', compact: true),
                  ],
                ),
              ),
              const SizedBox(width: TempoSpace.xs),
              AnimatedSlide(
                offset: Offset(hovered ? 0.18 : 0, 0),
                duration: TempoMotion.of(context, TempoDuration.base),
                curve: TempoCurve.gentle,
                child: TempoIcon(
                  TempoGlyph.chevronRight,
                  size: 16,
                  color: hovered ? c.textPrimary : c.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
