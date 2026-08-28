import 'package:flutter/material.dart';

import '../../../core/motion/tempo_animations.dart';
import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';

@immutable
class TempoSegment<T> {
  const TempoSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// A segmented switch with a gliding indicator. Used wherever a view offers
/// alternative measures of the same data.
class TempoSegmented<T> extends StatelessWidget {
  const TempoSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.height = 36,
  });

  final List<TempoSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final int count = segments.length;
    final int index = segments.indexWhere(
      (TempoSegment<T> segment) => segment.value == value,
    );
    final double alignmentX = count > 1
        ? -1 + 2 * (index < 0 ? 0 : index) / (count - 1)
        : 0;

    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        color: c.glassFill,
        border: Border.all(color: c.border),
      ),
      child: Stack(
        children: <Widget>[
          if (index >= 0)
            AnimatedAlign(
              alignment: Alignment(alignmentX, 0),
              duration: TempoMotion.of(context, TempoDuration.slow),
              curve: TempoCurve.emphasized,
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height / 2),
                    gradient: context.tempo.selectionGradient,
                    border: Border.all(
                      color: c.accent.withValues(alpha: 0.30),
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: <Widget>[
              for (int i = 0; i < count; i++)
                Expanded(
                  child: HoverBuilder(
                    onTap: () => onChanged(segments[i].value),
                    builder: (BuildContext context, bool hovered) {
                      final bool selected = i == index;
                      return Center(
                        child: AnimatedDefaultTextStyle(
                          duration: TempoMotion.of(
                            context,
                            TempoDuration.base,
                          ),
                          curve: TempoCurve.gentle,
                          style:
                              context.typo.labelMedium?.copyWith(
                                color: selected
                                    ? c.textPrimary
                                    : (hovered
                                          ? c.textPrimary
                                          : c.textSecondary),
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ) ??
                              const TextStyle(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: TempoSpace.sm,
                            ),
                            child: Text(
                              segments[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
