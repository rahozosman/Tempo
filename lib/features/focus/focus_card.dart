import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/tempo_motion.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/utilities/tempo_format.dart';
import '../../domain/analytics/app_category.dart';
import '../../domain/tracking/focus_block.dart';
import '../../domain/tracking/usage_session.dart';
import '../../platform/usage_tracking/usage_tracking_providers.dart';
import '../../shared/widgets/charts/activity_ring.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/tempo_icon.dart';
import '../applications/category_controller.dart';
import 'focus_controller.dart';

/// A block of deliberate work: choose a length, start it, and see afterwards
/// how much of it actually stayed in work applications.
///
/// Nothing is guessed. The figure at the end comes from the sessions Tempo
/// recorded inside the block, which is also why it can be lower than you hoped.
class FocusCard extends ConsumerWidget {
  const FocusCard({super.key});

  static const List<Duration> _targets = <Duration>[
    Duration(minutes: 25),
    Duration(minutes: 50),
    Duration(minutes: 90),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TempoColors c = context.colors;
    final FocusState focus = ref.watch(focusProvider);
    final FocusController controller = ref.read(focusProvider.notifier);

    return GlassCard(
      hoverLift: false,
      padding: const EdgeInsets.all(TempoSpace.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          ActivityRing(
            active: focus.isRunning ? focus.elapsed : Duration.zero,
            idle: Duration.zero,
            reference: focus.target,
            size: 132,
            thickness: 10,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    focus.isRunning
                        ? TempoFormat.hm(focus.remaining)
                        : TempoFormat.hm(focus.target),
                    style: context.typo.headlineMedium,
                  ),
                  Text(
                    focus.isRunning ? 'left' : 'block',
                    style: context.typo.labelSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: TempoSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('FOCUS', style: context.typo.labelSmall),
                const SizedBox(height: TempoSpace.xs),
                AnimatedSwitcher(
                  duration: TempoMotion.of(context, TempoDuration.base),
                  child: focus.isRunning
                      ? _Running(
                          key: const ValueKey<String>('running'),
                          focus: focus,
                          onStop: controller.finish,
                        )
                      : _Idle(
                          key: const ValueKey<String>('idle'),
                          focus: focus,
                          onTarget: controller.setTarget,
                          onStart: controller.start,
                        ),
                ),
                const SizedBox(height: TempoSpace.md),
                Container(height: 1, color: c.border),
                const SizedBox(height: TempoSpace.sm),
                const _History(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle({
    super.key,
    required this.focus,
    required this.onTarget,
    required this.onStart,
  });

  final FocusState focus;
  final ValueChanged<Duration> onTarget;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final FocusBlock? last = focus.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          last == null
              ? 'Set a block, work through it, and see how much of it stayed '
                    'work.'
              : 'Last block: ${TempoFormat.hm(last.focused)} focused of '
                    '${TempoFormat.hm(last.length)} — '
                    '${TempoFormat.percent(last.share)}.',
          style: context.typo.bodyMedium,
        ),
        const SizedBox(height: TempoSpace.md),
        Row(
          children: <Widget>[
            for (final Duration target in FocusCard._targets) ...<Widget>[
              _TargetChip(
                target: target,
                selected: target == focus.target,
                onTap: () => onTarget(target),
              ),
              const SizedBox(width: TempoSpace.xs),
            ],
            const Spacer(),
            GlassButton(
              label: 'Start focus',
              glyph: TempoGlyph.play,
              style: GlassButtonStyle.primary,
              compact: true,
              onPressed: onStart,
            ),
          ],
        ),
      ],
    );
  }
}

class _Running extends ConsumerWidget {
  const _Running({super.key, required this.focus, required this.onStop});

  final FocusState focus;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TempoColors c = context.colors;
    final UsageSession? current = ref
        .watch(usageTrackerProvider)
        .currentSession;
    final Map<String, AppCategory> categories =
        ref.watch(applicationCategoriesProvider).value ??
        const <String, AppCategory>{};
    final AppCategory? category = current == null
        ? null
        : categoryOf(current.applicationId, categories);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          current == null
              ? 'Running. Nothing in front right now.'
              : 'In ${current.applicationName} — '
                    '${category!.isFocus ? 'this counts as focus' : 'this does not count as focus'}.',
          style: context.typo.bodyMedium?.copyWith(
            color: category == null
                ? c.textSecondary
                : (category.isFocus ? c.textPrimary : c.warning),
          ),
        ),
        const SizedBox(height: TempoSpace.md),
        Row(
          children: <Widget>[
            Text(
              '${TempoFormat.hm(focus.elapsed)} of '
              '${TempoFormat.hm(focus.target)}',
              style: context.typo.titleSmall,
            ),
            const Spacer(),
            GlassButton(
              label: 'End block',
              glyph: TempoGlyph.pause,
              compact: true,
              onPressed: onStop,
            ),
          ],
        ),
      ],
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.target,
    required this.selected,
    required this.onTap,
  });

  final Duration target;
  final bool selected;
  final VoidCallback onTap;

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
            color: selected ? c.accent.withValues(alpha: 0.18) : c.glassFill,
            border: Border.all(
              color: selected
                  ? c.accent.withValues(alpha: 0.5)
                  : c.border,
            ),
          ),
          child: Text(
            '${target.inMinutes}m',
            style: context.typo.labelMedium?.copyWith(
              color: selected ? c.textPrimary : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<FocusBlock> blocks =
        ref.watch(recentFocusProvider).value ?? const <FocusBlock>[];
    if (blocks.isEmpty) {
      return Text(
        'Finished blocks are kept, so you can see how focus goes over time.',
        style: context.typo.bodySmall,
      );
    }

    return Wrap(
      spacing: TempoSpace.md,
      runSpacing: TempoSpace.xs,
      children: <Widget>[
        for (final FocusBlock block in blocks)
          Tooltip(
            message:
                '${TempoFormat.dayShort(block.start)} '
                '${TempoFormat.clock(block.start)}\n'
                '${TempoFormat.hm(block.focused)} focused of '
                '${TempoFormat.hm(block.length)}',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: block.share >= 0.6
                        ? context.colors.accentSoft
                        : context.colors.textTertiary,
                  ),
                ),
                const SizedBox(width: TempoSpace.xs - 2),
                Text(
                  TempoFormat.percent(block.share),
                  style: context.typo.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
