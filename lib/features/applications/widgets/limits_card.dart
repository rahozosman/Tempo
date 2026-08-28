import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_palette.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/utilities/tempo_format.dart';
import '../../../domain/analytics/app_usage.dart';
import '../../../shared/widgets/app_glyph.dart';
import '../../../shared/widgets/glass/glass_card.dart';
import '../applications_controller.dart';
import '../limits_controller.dart';

/// How today stands against the daily limits that have been set.
///
/// Absent entirely when nothing has a limit: an empty card teaching a feature
/// is worse than no card at all.
class LimitsCard extends ConsumerWidget {
  const LimitsCard({super.key, required this.apps});

  /// Today's applications, ranked.
  final List<AppUsage> apps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, Duration> limits =
        ref.watch(applicationLimitsProvider).value ??
        const <String, Duration>{};
    final List<LimitProgress> progress = limitsFor(apps, limits);
    if (progress.isEmpty) {
      return const SizedBox.shrink();
    }

    final int reached = progress
        .where((LimitProgress p) => p.reached)
        .length;

    return GlassCard(
      hoverLift: false,
      padding: const EdgeInsets.all(TempoSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('DAILY LIMITS', style: context.typo.labelSmall),
              ),
              Text(
                reached == 0
                    ? 'All within'
                    : '$reached of ${progress.length} reached',
                style: context.typo.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.md),
          for (final LimitProgress item in progress)
            _LimitRow(
              progress: item,
              onOpen: () => openApplication(ref, item.usage),
            ),
        ],
      ),
    );
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({required this.progress, required this.onOpen});

  final LimitProgress progress;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final AppUsage app = progress.usage;
    final Color tone = progress.reached
        ? c.warning
        : TempoPalette.toneFor(c, app.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: TempoSpace.md),
      child: GestureDetector(
        onTap: onOpen,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            children: <Widget>[
              AppGlyph(id: app.id, name: app.name, size: 30),
              const SizedBox(width: TempoSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            app.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typo.titleSmall,
                          ),
                        ),
                        Text(
                          '${TempoFormat.hm(app.duration)} / '
                          '${TempoFormat.hm(progress.limit)}',
                          style: context.typo.labelMedium?.copyWith(
                            color: progress.reached
                                ? c.warning
                                : c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TempoSpace.xs - 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 7,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            ColoredBox(
                              color: c.glassFill.withValues(alpha: 0.09),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: progress.share,
                              ),
                              duration: TempoMotion.of(
                                context,
                                const Duration(milliseconds: 900),
                              ),
                              curve: TempoCurve.entrance,
                              builder:
                                  (
                                    BuildContext context,
                                    double t,
                                    Widget? child,
                                  ) => FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: t,
                                    child: child,
                                  ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: TempoPalette.gradientFor(tone),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      progress.reached
                          ? '${TempoFormat.hm(progress.over)} past the limit'
                          : '${TempoFormat.hm(progress.remaining)} left today',
                      style: context.typo.bodySmall?.copyWith(
                        fontSize: 11,
                        color: progress.reached ? c.warning : c.textTertiary,
                      ),
                    ),
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

/// The chips that set, change or clear an application's daily limit.
class LimitPicker extends ConsumerWidget {
  const LimitPicker({super.key, required this.applicationId});

  static const List<Duration?> _choices = <Duration?>[
    null,
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 3),
    Duration(hours: 4),
  ];

  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TempoColors c = context.colors;
    final Duration? current =
        (ref.watch(applicationLimitsProvider).value ??
        const <String, Duration>{})[applicationId];

    return Wrap(
      spacing: TempoSpace.xs,
      runSpacing: TempoSpace.xs,
      alignment: WrapAlignment.end,
      children: <Widget>[
        for (final Duration? choice in _choices)
          _LimitChip(
            label: choice == null
                ? 'No limit'
                : (choice.inMinutes < 60
                      ? '${choice.inMinutes}m'
                      : '${choice.inHours}h'),
            selected: choice == current,
            onTap: () => setApplicationLimit(ref, applicationId, choice),
            tone: c.accent,
          ),
      ],
    );
  }
}

class _LimitChip extends StatelessWidget {
  const _LimitChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.tone,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: TempoMotion.of(context, TempoDuration.base),
          curve: TempoCurve.gentle,
          padding: const EdgeInsets.symmetric(
            horizontal: TempoSpace.sm,
            vertical: TempoSpace.xs - 1,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TempoRadius.sm),
            color: selected ? tone.withValues(alpha: 0.18) : c.glassFill,
            border: Border.all(
              color: selected ? tone.withValues(alpha: 0.55) : c.border,
            ),
          ),
          child: Text(
            label,
            style: context.typo.labelMedium?.copyWith(
              color: selected ? c.textPrimary : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
