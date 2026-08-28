import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/motion/tempo_animations.dart';
import '../../../core/motion/tempo_motion.dart';
import '../../../core/platform/tempo_platform.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../data/analytics/analytics_providers.dart';
import '../../../shared/widgets/tempo_icon.dart';

/// Tempo draws its own title bar so the window reads as one continuous glass
/// surface. macOS keeps its native window buttons (the sidebar reserves room
/// for them); Windows gets Tempo caption buttons on the right.
class TempoTitleBar extends StatefulWidget {
  const TempoTitleBar({super.key});

  @override
  State<TempoTitleBar> createState() => _TempoTitleBarState();
}

class _TempoTitleBarState extends State<TempoTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    if (TempoPlatform.isDesktop) {
      windowManager.addListener(this);
      _syncMaximized();
    }
  }

  Future<void> _syncMaximized() async {
    final bool maximized = await windowManager.isMaximized();
    if (mounted && maximized != _maximized) {
      setState(() => _maximized = maximized);
    }
  }

  @override
  void dispose() {
    if (TempoPlatform.isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() => _maximized = true);
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() => _maximized = false);
    }
  }

  Future<void> _toggleMaximize() async {
    if (!TempoPlatform.isDesktop) {
      return;
    }
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TempoSizes.titleBar,
      child: Row(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (DragStartDetails _) {
                if (TempoPlatform.isDesktop) {
                  windowManager.startDragging();
                }
              },
              onDoubleTap: _toggleMaximize,
              child: const SizedBox.expand(),
            ),
          ),
          const _PreviewBadge(),
          if (TempoPlatform.drawsOwnCaptionButtons)
            Row(
              children: <Widget>[
                _CaptionButton(
                  glyph: TempoGlyph.minimize,
                  tooltip: 'Minimise',
                  onTap: () => windowManager.minimize(),
                ),
                _CaptionButton(
                  glyph: _maximized
                      ? TempoGlyph.restore
                      : TempoGlyph.maximize,
                  tooltip: _maximized ? 'Restore' : 'Maximise',
                  onTap: _toggleMaximize,
                ),
                _CaptionButton(
                  glyph: TempoGlyph.close,
                  tooltip: 'Close',
                  danger: true,
                  onTap: () => windowManager.close(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Shown whenever the interface is being fed sample data, so a screenshot can
/// never be mistaken for a measurement. Only ever visible in a debug build.
class _PreviewBadge extends ConsumerWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(previewDataProvider)) {
      return const SizedBox.shrink();
    }
    final TempoColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: TempoSpace.xs),
      child: Tooltip(
        message:
            'Sample data, shown so the interface can be designed. '
            'Turn it off in Settings to see real measurements.',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TempoSpace.xs + 2,
            vertical: TempoSpace.xxs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TempoRadius.xs),
            color: c.warning.withValues(alpha: 0.14),
            border: Border.all(color: c.warning.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.warning,
                ),
              ),
              const SizedBox(width: TempoSpace.xxs + 2),
              Text(
                'Preview data',
                style: context.typo.labelMedium?.copyWith(
                  color: c.textPrimary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptionButton extends StatelessWidget {
  const _CaptionButton({
    required this.glyph,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  final TempoGlyph glyph;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Tooltip(
      message: tooltip,
      preferBelow: true,
      child: HoverBuilder(
        onTap: onTap,
        builder: (BuildContext context, bool hovered) => AnimatedContainer(
          duration: TempoMotion.of(context, TempoDuration.quick),
          curve: TempoCurve.gentle,
          width: TempoSizes.captionButton,
          height: TempoSizes.titleBar,
          color: hovered
              ? (danger
                    ? c.danger.withValues(alpha: 0.86)
                    : c.glassFillStrong)
              : Colors.transparent,
          child: Center(
            child: TempoIcon(
              glyph,
              size: 15,
              strokeWidth: 1.5,
              color: hovered
                  ? (danger ? const Color(0xFFFFFFFF) : c.textPrimary)
                  : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
