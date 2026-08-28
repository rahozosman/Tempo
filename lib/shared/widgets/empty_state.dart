import 'package:flutter/material.dart';

import '../../core/motion/tempo_animations.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import 'tempo_icon.dart';

/// The shape every "nothing here yet" moment takes. Calm and explanatory,
/// never an error and never an apology.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.glyph = TempoGlyph.sparkle,
    this.action,
    this.tone,
  });

  final String title;
  final String message;
  final TempoGlyph glyph;
  final Widget? action;

  /// Accent for the halo. Defaults to the product accent; error states pass
  /// the danger tone.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final Color accent = tone ?? c.accent;
    final Color halo = tone ?? c.accentAlt;
    return Center(
      child: TempoEntrance(
        rise: 18,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      accent.withValues(alpha: 0.18),
                      halo.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.24)),
                  boxShadow: context.tempo.glowOf(accent, 0.6),
                ),
                child: Center(
                  child: TempoIcon(
                    glyph,
                    size: 32,
                    color: tone ?? c.accentSoft,
                  ),
                ),
              ),
              const SizedBox(height: TempoSpace.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.typo.headlineSmall,
              ),
              const SizedBox(height: TempoSpace.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.typo.bodyMedium,
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: TempoSpace.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
