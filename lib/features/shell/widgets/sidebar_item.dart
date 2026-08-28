import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/motion/tempo_animations.dart';
import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../shared/widgets/tempo_icon.dart';
import '../../navigation/nav_destination.dart';

/// One sidebar row. The selection pill lives in the sidebar itself so it can
/// glide between rows; this widget only owns hover, icon and label.
class SidebarItem extends StatelessWidget {
  const SidebarItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.expansion,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;

  /// 0 = icon rail, 1 = full sidebar.
  final double expansion;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final Duration duration = TempoMotion.of(context, TempoDuration.base);

    Widget row = HoverBuilder(
      onTap: onTap,
      builder: (BuildContext context, bool hovered) {
        final Color foreground = selected
            ? c.textPrimary
            : (hovered ? c.textPrimary : c.textSecondary);
        // The hover pill is drawn by the sidebar so it can glide between rows;
        // this widget only answers with its own ink.
        return SizedBox(
          height: context.sized(TempoSizes.navItem),
          child: Row(
            children: <Widget>[
              SizedBox(width: lerpDouble(14, 10, expansion)),
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: selected ? c.accentSoft : foreground),
                duration: duration,
                curve: TempoCurve.gentle,
                builder: (BuildContext context, Color? value, Widget? child) =>
                    TempoIcon(
                      destination.glyph,
                      size: 18,
                      color: value ?? foreground,
                    ),
              ),
              Flexible(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: 0,
                    maxWidth: 92,
                    child: Opacity(
                      opacity: expansion,
                      child: Padding(
                        padding: const EdgeInsets.only(left: TempoSpace.xs),
                        child: AnimatedDefaultTextStyle(
                          duration: duration,
                          curve: TempoCurve.gentle,
                          style:
                              context.typo.labelLarge?.copyWith(
                                fontSize: 13,
                                color: foreground,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ) ??
                              const TextStyle(),
                          child: Text(
                            destination.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (expansion < 0.5) {
      row = Tooltip(message: destination.hint, preferBelow: false, child: row);
    }

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: row,
    );
  }
}
