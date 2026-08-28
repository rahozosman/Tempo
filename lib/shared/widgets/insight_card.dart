import 'package:flutter/material.dart';

import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import 'glass/glass_card.dart';
import 'tempo_icon.dart';

/// One observation: the figure, and the sentence behind it.
@immutable
class InsightLine {
  const InsightLine({
    required this.glyph,
    required this.headline,
    required this.detail,
  });

  final TempoGlyph glyph;
  final String headline;
  final String detail;
}

/// A single observation drawn from stored data: the figure, then the sentence
/// that explains it. Nothing here is ever written unless the numbers exist.
class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.glyph,
    required this.headline,
    required this.detail,
    this.tone,
    this.onTap,
  });

  final TempoGlyph glyph;
  final String headline;
  final String detail;
  final Color? tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final Color resolved = tone ?? c.accent;

    return GlassCard(
      onTap: onTap,
      semanticLabel: '$headline. $detail',
      padding: const EdgeInsets.all(TempoSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TempoRadius.sm),
              color: resolved.withValues(alpha: 0.13),
              border: Border.all(color: resolved.withValues(alpha: 0.24)),
            ),
            child: Center(
              child: TempoIcon(glyph, size: 18, color: resolved),
            ),
          ),
          const SizedBox(width: TempoSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.headlineSmall,
                ),
                const SizedBox(height: TempoSpace.xxs),
                Text(detail, style: context.typo.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
