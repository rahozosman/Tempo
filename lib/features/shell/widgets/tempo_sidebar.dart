import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_info.dart';
import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../shared/widgets/tempo_icon.dart';
import '../../../shared/widgets/tempo_mark.dart';
import '../../applications/applications_controller.dart';
import '../../navigation/nav_destination.dart';
import '../../navigation/navigation_controller.dart';
import 'sidebar_item.dart';
import 'tracking_indicator.dart';

/// The permanent left rail: brand, destinations and live tracking state.
///
/// Collapses to an icon rail on narrow windows. One [TweenAnimationBuilder]
/// drives the width, the icon insets and the label fade so the change reads as
/// a single movement.
class TempoSidebar extends ConsumerWidget {
  const TempoSidebar({super.key, required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int selected = ref.watch(navigationProvider);
    final TempoColors c = context.colors;
    final bool isDark = context.tempo.isDark;
    final double target = collapsed ? 0 : 1;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: target, end: target),
      duration: TempoMotion.of(context, TempoDuration.slow),
      curve: TempoCurve.emphasized,
      builder: (BuildContext context, double t, Widget? child) {
        final double width = lerpDouble(
          TempoSizes.sidebarRail,
          TempoSizes.sidebarExpanded,
          t,
        )!;
        return SizedBox(
          width: width,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: c.border)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      c.backdrop.withValues(alpha: isDark ? 0.40 : 0.26),
                      c.backdrop.withValues(alpha: isDark ? 0.62 : 0.42),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: TempoSizes.titleBar),
                    _Brand(expansion: t),
                    const SizedBox(height: TempoSpace.lg),
                    Expanded(
                      child: _NavList(expansion: t, selected: selected),
                    ),
                    _Footer(expansion: t),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Brand extends StatefulWidget {
  const _Brand({required this.expansion});

  final double expansion;

  @override
  State<_Brand> createState() => _BrandState();
}

/// The brand lockup: the mark inside its own orbit, the name in the product
/// gradient, and the product's job spelled out underneath.
///
/// One point travels the orbit, and it takes eighteen seconds to go round, so
/// the corner of the window is alive without ever asking to be looked at.
class _BrandState extends State<_Brand> with SingleTickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (!TempoMotion.reduced(context)) {
      _orbit.repeat();
    }
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: TempoSpace.xs),
      child: SizedBox(
        height: 42,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 30,
              height: 30,
              child: AnimatedBuilder(
                animation: _orbit,
                builder: (BuildContext context, Widget? child) => CustomPaint(
                  painter: _BrandOrbit(
                    colors: c,
                    angle: _orbit.value * 2 * math.pi,
                  ),
                  child: child,
                ),
                child: const Center(child: TempoMark(size: 20, glow: false)),
              ),
            ),
            Flexible(
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 0,
                  maxWidth: 92,
                  child: Opacity(
                    opacity: widget.expansion,
                    child: Padding(
                      padding: const EdgeInsets.only(left: TempoSpace.sm + 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (Rect bounds) => LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[c.textPrimary, c.accentSoft],
                            ).createShader(bounds),
                            child: Text(
                              AppInfo.name,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.clip,
                              style: context.typo.titleMedium?.copyWith(
                                letterSpacing: 0.4,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'SCREEN TIME',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: context.typo.labelSmall?.copyWith(
                              fontSize: 8,
                              letterSpacing: 1.4,
                              color: c.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The mark's orbit: a hairline track and the single point running it.
class _BrandOrbit extends CustomPainter {
  const _BrandOrbit({required this.colors, required this.angle});

  final TempoColors colors;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - 1.5;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.border,
    );

    final Offset dot =
        centre + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(
      dot,
      4.5,
      Paint()..color = colors.accentSoft.withValues(alpha: 0.16),
    );
    canvas.drawCircle(dot, 2, Paint()..color = colors.accentSoft);
  }

  @override
  bool shouldRepaint(_BrandOrbit old) =>
      old.angle != angle ||
      old.colors.accentSoft != colors.accentSoft ||
      old.colors.border != colors.border;
}

class _NavList extends ConsumerStatefulWidget {
  const _NavList({required this.expansion, required this.selected});

  final double expansion;
  final int selected;

  @override
  ConsumerState<_NavList> createState() => _NavListState();
}

class _NavListState extends ConsumerState<_NavList> {
  static const double _step = TempoSizes.navItem + TempoSizes.navGap;

  int? _hovered;

  /// The row the hover pill is parked on, kept after the pointer leaves so the
  /// pill fades out where it stood rather than snapping back to the top.
  int _anchor = 0;

  void _hover(int? index) {
    if (_hovered == index) {
      return;
    }
    setState(() {
      _hovered = index;
      if (index != null) {
        _anchor = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final int selected = widget.selected;
    final Duration glide = TempoMotion.of(context, TempoDuration.slow);
    final bool showing = _hovered != null && _hovered != selected;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: TempoSpace.xxs),
      child: Stack(
        children: <Widget>[
          AnimatedPositioned(
            duration: glide,
            curve: TempoCurve.emphasized,
            top: selected * _step,
            left: TempoSpace.xs,
            right: TempoSpace.xs,
            height: TempoSizes.navItem,
            child: const _SelectionPill(),
          ),
          // A second, quieter pill that follows the pointer between rows, the
          // way a Mac source list tracks the mouse.
          AnimatedPositioned(
            duration: TempoMotion.of(context, TempoDuration.base),
            curve: TempoCurve.gentle,
            top: _anchor * _step,
            left: TempoSpace.xs,
            right: TempoSpace.xs,
            height: TempoSizes.navItem,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: showing ? 1 : 0,
                duration: TempoMotion.of(context, TempoDuration.base),
                curve: TempoCurve.gentle,
                child: const _HoverPill(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TempoSpace.xs),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < kDestinations.length; i++) ...<Widget>[
                  MouseRegion(
                    onEnter: (_) => _hover(i),
                    onExit: (_) {
                      if (_hovered == i) {
                        _hover(null);
                      }
                    },
                    child: SidebarItem(
                      destination: kDestinations[i],
                      selected: i == selected,
                      expansion: widget.expansion,
                      // The sidebar always goes to the root of a section, so
                      // Applications returns to the ranked list rather than the
                      // application that happened to be open last.
                      onTap: () {
                        if (kDestinations[i].section ==
                            TempoSection.applications) {
                          ref
                              .read(selectedApplicationProvider.notifier)
                              .clear();
                        }
                        ref.read(navigationProvider.notifier).select(i);
                      },
                    ),
                  ),
                  if (i != kDestinations.length - 1)
                    const SizedBox(height: TempoSizes.navGap),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The pointer pill: glass, no accent, so it never competes with the
/// selection it slides past.
class _HoverPill extends StatelessWidget {
  const _HoverPill();

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TempoRadius.md - 2),
        color: c.glassFill,
        border: Border.all(color: c.border),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SelectionPill extends StatelessWidget {
  const _SelectionPill();

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final TempoTheme theme = context.tempo;
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TempoRadius.md - 2),
              gradient: theme.selectionGradient,
              border: Border.all(color: c.accent.withValues(alpha: 0.28)),
              boxShadow: theme.accentGlow(0.75),
            ),
            child: const SizedBox.expand(),
          ),
          Positioned(
            left: 0,
            top: 13,
            bottom: 13,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                gradient: theme.accentGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.expansion});

  final double expansion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TempoSpace.sm,
        TempoSpace.xs,
        TempoSpace.sm,
        TempoSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TrackingIndicator(expansion: expansion),
          const SizedBox(height: TempoSpace.sm),
          Opacity(
            opacity: expansion,
            child: SizedBox(
              height: 16,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 0,
                  // The full width the expanded sidebar has to give. The line
                  // is laid out at that width whatever the rail is doing, so
                  // the fold clips it rather than reflowing it.
                  maxWidth: TempoSizes.sidebarExpanded - TempoSpace.sm * 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(width: TempoSpace.xxs),
                      TempoIcon(
                        TempoGlyph.lock,
                        size: 12,
                        color: context.colors.textTertiary,
                      ),
                      const SizedBox(width: TempoSpace.xs - 2),
                      Flexible(
                        child: Tooltip(
                          message: AppInfo.privacyLine,
                          child: Text(
                            'Private',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: context.typo.bodySmall?.copyWith(
                              fontSize: 11,
                              color: context.colors.textTertiary,
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
        ],
      ),
    );
  }
}
