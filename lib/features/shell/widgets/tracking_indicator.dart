import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../domain/tracking/tracking_status.dart';
import '../../settings/preferences_controller.dart';
import '../../../core/motion/tempo_animations.dart';
import '../../../shared/widgets/glass/glass_surface.dart';

/// The live tracking pill at the foot of the sidebar.
///
/// It reports the real state of the tracking engine. The halo only breathes
/// while tracking is actually running.
class TrackingIndicator extends ConsumerStatefulWidget {
  const TrackingIndicator({super.key, required this.expansion});

  final double expansion;

  @override
  ConsumerState<TrackingIndicator> createState() => _TrackingIndicatorState();
}

class _TrackingIndicatorState extends ConsumerState<TrackingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TempoDuration.pulse,
  );

  @override
  void initState() {
    super.initState();
    if (ref.read(trackingStatusProvider).isLive) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sync(TrackingStatus status) {
    final bool shouldRun = status.isLive && !TempoMotion.reduced(context);
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TrackingStatus>(trackingStatusProvider, (
      TrackingStatus? previous,
      TrackingStatus next,
    ) {
      _sync(next);
    });

    final TrackingStatus status = ref.watch(trackingStatusProvider);
    final TempoColors c = context.colors;
    final Color dot = switch (status) {
      TrackingStatus.notStarted => c.textTertiary,
      TrackingStatus.active => c.positive,
      TrackingStatus.paused => c.warning,
      TrackingStatus.unavailable => c.danger,
    };

    final bool canToggle =
        status == TrackingStatus.active || status == TrackingStatus.paused;

    return Semantics(
      label: '${status.title}. ${status.detail}',
      button: canToggle,
      child: Tooltip(
        message:
            '${status.detail}\n${switch (status) {
              TrackingStatus.active => 'Pause tracking',
              TrackingStatus.paused => 'Resume tracking',
              TrackingStatus.notStarted => 'Tracking has not started yet',
              TrackingStatus.unavailable => 'Tempo cannot measure application usage on this system',
            }}',
        child: HoverBuilder(
          cursor: canToggle
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onTap: canToggle
              ? () => ref
                    .read(preferencesProvider.notifier)
                    .setTrackingEnabled(
                      enabled: status != TrackingStatus.active,
                    )
              : null,
          builder: (BuildContext context, bool hovered) => GlassSurface(
            radius: TempoRadius.md,
            padding: const EdgeInsets.symmetric(
              horizontal: TempoSpace.sm,
              vertical: TempoSpace.xs,
            ),
            shadows: const <BoxShadow>[],
            fill: hovered && canToggle ? c.glassFillStrong : null,
            child: SizedBox(
              // One line now: the rail is half the width it was, and the status
              // detail reads in the tooltip instead.
              height: 26,
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        if (status.isLive)
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (BuildContext context, Widget? child) {
                              final double v = _controller.value;
                              final double size = 9 + 11 * v;
                              return Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: dot.withValues(alpha: (1 - v) * 0.32),
                                ),
                              );
                            },
                          ),
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dot,
                            boxShadow: context.tempo.glowOf(dot, 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: 0,
                        maxWidth: 84,
                        child: Opacity(
                          opacity: widget.expansion,
                          child: Padding(
                            padding: const EdgeInsets.only(left: TempoSpace.xs),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                status.title,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.clip,
                                style: context.typo.titleSmall?.copyWith(
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
