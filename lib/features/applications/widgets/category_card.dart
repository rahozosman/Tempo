import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/utilities/tempo_format.dart';
import '../../../domain/analytics/app_category.dart';
import '../../../domain/analytics/app_usage.dart';
import '../../../shared/widgets/glass/glass_card.dart';
import '../category_controller.dart';

/// Where a period's time went, by kind of application rather than by name.
///
/// One bar, split in proportion, with the categories that actually appear
/// listed underneath. Applications with no category yet fall under "Other" and
/// can be moved from their own page.
class CategoryCard extends ConsumerWidget {
  const CategoryCard({
    super.key,
    required this.apps,
    required this.title,
    this.caption,
  });

  /// Usually the ranked applications of a day, week, month or year.
  final List<AppUsage> apps;

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TempoColors c = context.colors;
    final Map<String, AppCategory> categories =
        ref.watch(applicationCategoriesProvider).value ??
        const <String, AppCategory>{};
    final CategoryBreakdown breakdown = CategoryBreakdown.of(apps, categories);

    if (breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

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
                child: Text(
                  title.toUpperCase(),
                  style: context.typo.labelSmall,
                ),
              ),
              Text(
                '${TempoFormat.hm(breakdown.focus)} focused · '
                '${TempoFormat.percent(breakdown.focusShare)}',
                style: context.typo.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          _SplitBar(breakdown: breakdown),
          const SizedBox(height: TempoSpace.lg),
          Wrap(
            spacing: TempoSpace.lg,
            runSpacing: TempoSpace.sm,
            children: <Widget>[
              for (final MapEntry<AppCategory, Duration> entry
                  in breakdown.totals.entries)
                _Legend(
                  category: entry.key,
                  value: entry.value,
                  share: breakdown.shareOf(entry.key),
                ),
            ],
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: TempoSpace.md),
            Text(
              caption!,
              style: context.typo.bodySmall?.copyWith(color: c.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.breakdown});

  final CategoryBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        height: 14,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: TempoMotion.of(
            context,
            const Duration(milliseconds: 900),
          ),
          curve: TempoCurve.entrance,
          builder: (BuildContext context, double t, Widget? child) => Row(
            children: <Widget>[
              for (final MapEntry<AppCategory, Duration> entry
                  in breakdown.totals.entries)
                Expanded(
                  flex: (breakdown.shareOf(entry.key) * 10000 * t)
                      .round()
                      .clamp(0, 10000),
                  child: Tooltip(
                    message:
                        '${entry.key.label} · ${TempoFormat.hm(entry.value)}',
                    child: ColoredBox(color: entry.key.tone(c)),
                  ),
                ),
              // Holds the bar's width steady while the split animates in.
              Expanded(
                flex: ((1 - t) * 10000).round().clamp(0, 10000),
                child: ColoredBox(
                  color: c.glassFill.withValues(alpha: 0.09),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.category,
    required this.value,
    required this.share,
  });

  final AppCategory category;
  final Duration value;
  final double share;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: category.tone(c),
          ),
        ),
        const SizedBox(width: TempoSpace.xs),
        Text(category.label, style: context.typo.bodyMedium),
        const SizedBox(width: TempoSpace.xs),
        Text(
          '${TempoFormat.hm(value)} · ${TempoFormat.percent(share)}',
          style: context.typo.labelMedium?.copyWith(color: c.textPrimary),
        ),
      ],
    );
  }
}

/// The chips that move an application from one category to another.
class CategoryPicker extends ConsumerWidget {
  const CategoryPicker({super.key, required this.applicationId});

  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TempoColors c = context.colors;
    final Map<String, AppCategory> categories =
        ref.watch(applicationCategoriesProvider).value ??
        const <String, AppCategory>{};
    final AppCategory current = categoryOf(applicationId, categories);

    return Wrap(
      spacing: TempoSpace.xs,
      runSpacing: TempoSpace.xs,
      alignment: WrapAlignment.end,
      children: <Widget>[
        for (final AppCategory category in AppCategory.values)
          _CategoryChip(
            category: category,
            selected: category == current,
            onTap: () =>
                setApplicationCategory(ref, applicationId, category),
            tone: category.tone(c),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
    required this.tone,
  });

  final AppCategory category;
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
            color: selected
                ? tone.withValues(alpha: 0.18)
                : c.glassFill,
            border: Border.all(
              color: selected ? tone.withValues(alpha: 0.55) : c.border,
            ),
          ),
          child: Text(
            category.label,
            style: context.typo.labelMedium?.copyWith(
              color: selected ? c.textPrimary : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
