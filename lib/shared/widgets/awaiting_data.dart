import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../domain/tracking/tracking_status.dart';
import 'empty_state.dart';
import 'glass/glass_surface.dart';
import 'tempo_icon.dart';

/// The empty state used by every analytics screen while there is nothing to
/// show. It reports the real state of the tracking engine underneath the
/// message rather than implying data is already on its way.
class AwaitingData extends ConsumerWidget {
  const AwaitingData({
    super.key,
    required this.title,
    required this.message,
    this.glyph = TempoGlyph.sparkle,
  });

  final String title;
  final String message;
  final TempoGlyph glyph;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TrackingStatus status = ref.watch(trackingStatusProvider);
    return EmptyState(
      title: title,
      message: message,
      glyph: glyph,
      action: _StatusChip(status: status),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final TrackingStatus status;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final Color tone = switch (status) {
      TrackingStatus.active => c.positive,
      TrackingStatus.paused => c.warning,
      TrackingStatus.unavailable => c.danger,
      TrackingStatus.notStarted => c.textTertiary,
    };

    return GlassSurface(
      radius: TempoRadius.md,
      padding: const EdgeInsets.symmetric(
        horizontal: TempoSpace.sm + 2,
        vertical: TempoSpace.xs + 1,
      ),
      shadows: const <BoxShadow>[],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tone,
              boxShadow: context.tempo.glowOf(tone, 0.8),
            ),
          ),
          const SizedBox(width: TempoSpace.xs),
          Text(
            status.title,
            style: context.typo.labelMedium?.copyWith(color: c.textPrimary),
          ),
          const SizedBox(width: TempoSpace.xxs - 2),
          Text('·', style: context.typo.labelMedium),
          const SizedBox(width: TempoSpace.xxs - 2),
          Text(status.detail, style: context.typo.labelMedium),
        ],
      ),
    );
  }
}
