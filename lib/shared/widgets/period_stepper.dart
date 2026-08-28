import 'package:flutter/material.dart';

import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import 'glass/glass_button.dart';
import 'glass/glass_surface.dart';
import 'tempo_icon.dart';

/// Moves a screen between periods: ‹ August 2026 ›, with a way back to the
/// present once you have wandered off it.
///
/// Stepping forward past the present is not offered, because there is nothing
/// there to show.
class PeriodStepper extends StatelessWidget {
  const PeriodStepper({
    super.key,
    required this.label,
    this.onPrevious,
    this.onNext,
    this.onReset,
    this.resetLabel = 'Now',
    this.width = 150,
  });

  final String label;

  /// Null when there is nothing earlier to show.
  final VoidCallback? onPrevious;

  /// Null when the period showing is already the current one.
  final VoidCallback? onNext;

  /// Shown only when the period showing is not the current one.
  final VoidCallback? onReset;

  final String resetLabel;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (onReset != null) ...<Widget>[
          GlassButton(
            label: resetLabel,
            style: GlassButtonStyle.quiet,
            compact: true,
            onPressed: onReset,
          ),
          const SizedBox(width: TempoSpace.xs),
        ],
        GlassSurface(
          radius: TempoRadius.md,
          padding: const EdgeInsets.all(3),
          shadows: const <BoxShadow>[],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Opacity(
                opacity: onPrevious == null ? 0.3 : 1,
                child: GlassIconButton(
                  glyph: TempoGlyph.chevronLeft,
                  tooltip: onPrevious == null
                      ? 'Nothing earlier recorded'
                      : 'Previous',
                  size: 30,
                  onPressed: onPrevious,
                ),
              ),
              SizedBox(
                width: width,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.labelLarge,
                ),
              ),
              Opacity(
                opacity: onNext == null ? 0.3 : 1,
                child: GlassIconButton(
                  glyph: TempoGlyph.chevronRight,
                  tooltip: onNext == null ? 'Already the latest' : 'Next',
                  size: 30,
                  onPressed: onNext,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
