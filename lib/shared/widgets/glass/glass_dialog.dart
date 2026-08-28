import 'package:flutter/material.dart';

import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';
import '../tempo_icon.dart';
import 'glass_button.dart';
import 'glass_surface.dart';

/// The modal shell: a dimmed room, one raised glass panel, a title, the
/// content, and the actions along the bottom.
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const <Widget>[],
    this.width = 560,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final double width;

  /// Opens the dialog with the product's own fade and settle.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    final TempoColors colors = context.colors;
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: colors.scrim.withValues(alpha: 0.62),
      transitionDuration: TempoMotion.of(context, TempoDuration.base),
      pageBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondary,
          ) => Center(child: builder(context)),
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondary,
            Widget child,
          ) {
            final CurvedAnimation curved = CurvedAnimation(
              parent: animation,
              curve: TempoCurve.entrance,
              reverseCurve: TempoCurve.exit,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
                child: child,
              ),
            );
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(TempoSpace.xl),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: MediaQuery.sizeOf(context).height - 120,
        ),
        child: GlassSurface(
          radius: TempoRadius.xl,
          fill: c.surface.withValues(alpha: 0.94),
          blur: 18,
          shadows: context.tempo.panelShadow,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TempoSpace.xl,
                  TempoSpace.lg,
                  TempoSpace.md,
                  TempoSpace.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(title, style: context.typo.headlineSmall),
                          if (subtitle != null) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(subtitle!, style: context.typo.bodySmall),
                          ],
                        ],
                      ),
                    ),
                    GlassIconButton(
                      glyph: TempoGlyph.close,
                      tooltip: 'Close',
                      size: 32,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TempoSpace.xl,
                  ),
                  child: child,
                ),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TempoSpace.xl,
                    TempoSpace.lg,
                    TempoSpace.xl,
                    TempoSpace.lg,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: TempoSpace.xs,
                    runSpacing: TempoSpace.xs,
                    children: actions,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
