import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../core/layout/smooth_scroll.dart';
import '../../core/layout/tempo_breakpoints.dart';
import '../../core/motion/tempo_animations.dart';
import '../../core/motion/tempo_motion.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';

/// Shared page frame: a compact heading, a measured content column and the
/// same entrance rhythm on every screen.
///
/// The heading is chrome, not content, and it knows it: it sits on the page's
/// own background with no strip and no rule under it, and it steps out of the
/// way as soon as you scroll down, coming back the moment you scroll up.
class PageScaffold extends StatefulWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.leading,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final Widget? trailing;

  /// Sits to the left of the title, such as an application mark.
  final Widget? leading;

  @override
  State<PageScaffold> createState() => _PageScaffoldState();
}

class _PageScaffoldState extends State<PageScaffold>
    with SingleTickerProviderStateMixin {
  /// 1 while the heading is showing, 0 once it has been scrolled away. It
  /// drives height as well as opacity, so hiding it hands the room to the
  /// page rather than leaving a gap behind.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final CurvedAnimation _eased = CurvedAnimation(
    parent: _reveal,
    curve: TempoCurve.emphasized,
  );

  bool _shown = true;


  /// How strongly the top edge of the content is faded: 0 while the page is
  /// at rest, 1 once it has been scrolled and there is content passing under
  /// the heading. Kept out of [setState] so scrolling only repaints the mask.
  final ValueNotifier<double> _topFade = ValueNotifier<double>(0);

  /// Every page's main list scrolls through this, so a mouse wheel glides
  /// rather than stepping. Handed down as the primary controller, which any
  /// vertical list under the page picks up without being told.
  final SmoothScrollController _scroll = SmoothScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    _topFade.dispose();
    _eased.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _set({required bool shown}) {
    if (_shown == shown) {
      return;
    }
    _shown = shown;
    if (TempoMotion.reduced(context)) {
      _reveal.value = shown ? 1 : 0;
      return;
    }
    if (shown) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    _topFade.value = (notification.metrics.pixels / 24).clamp(0.0, 1.0);
    // The heading holds still. Hiding it as the page moved meant the space
    // above the list shrank and grew with every change of direction, and the
    // content lurched with it — which read as the page pulling at itself.
    // Scrolling now moves the list and nothing else.
    _set(shown: true);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gutter = TempoBreakpoints.gutter(constraints.maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TempoSizes.contentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TempoEntrance(
                  child: AnimatedBuilder(
                    animation: _eased,
                    builder: (BuildContext context, Widget? child) {
                      final double t = _eased.value.clamp(0.0, 1.0);
                      return ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: t,
                          child: Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, -8 * (1 - t)),
                              child: child,
                            ),
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        TempoSizes.titleBar + TempoSpace.xxs,
                        gutter,
                        TempoSpace.xs,
                      ),
                      child: _Header(
                        title: widget.title,
                        subtitle: widget.subtitle,
                        leading: widget.leading,
                        trailing: widget.trailing,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(gutter, 0, gutter, gutter),
                    child: TempoEntrance(
                      index: 1,
                      child: PrimaryScrollController(
                        controller: _scroll,
                        // Desktop lists do not take the primary controller
                        // by default; here they must, or the wheel keeps
                        // its steps.
                        automaticallyInheritForPlatforms: TargetPlatform.values
                            .toSet(),
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _onScroll,
                          // Waiting, failed and settled states are different
                          // widgets: crossfade between them rather than swapping
                          // one for the other in a single frame.
                          child: _EdgeFade(
                            topFade: _topFade,
                            child: AnimatedSwitcher(
                              duration: TempoMotion.of(
                                context,
                                TempoDuration.base,
                              ),
                              switchInCurve: TempoCurve.entrance,
                              switchOutCurve: TempoCurve.exit,
                              layoutBuilder:
                                  (Widget? current, List<Widget> previous) =>
                                      Stack(
                                        fit: StackFit.passthrough,
                                        alignment: Alignment.topCenter,
                                        children: <Widget>[
                                          ...previous,
                                          ?current,
                                        ],
                                      ),
                              child: widget.child,
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
        );
      },
    );
  }
}

/// The page's own line: a lit title, an optional word underneath, and
/// whatever that page keeps to hand on the right.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (leading != null) ...<Widget>[
          leading!,
          const SizedBox(width: TempoSpace.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _LitTitle(title),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 1),
                Text(subtitle!, style: context.typo.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: TempoSpace.lg),
          trailing!,
        ],
      ],
    );
  }
}

/// The page title, with the product's light running through it.
///
/// A band of accent and violet travels the word and leaves it in its own
/// colour again — always moving, never blinking, and still plain text to
/// anything that reads the screen. "Reduce motion" gets the still title.
class _LitTitle extends StatefulWidget {
  const _LitTitle(this.text);

  final String text;

  @override
  State<_LitTitle> createState() => _LitTitleState();
}

class _LitTitleState extends State<_LitTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
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
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final Widget text = Text(widget.text, style: context.typo.titleLarge);
    if (TempoMotion.reduced(context)) {
      return text;
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (Rect bounds) {
          // The band runs from off one end of the word to off the other, so
          // the title spends part of every cycle simply white.
          final double head = -0.6 + 2.2 * _controller.value;
          double at(double offset) => (head + offset).clamp(0.0, 1.0);
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              c.textPrimary,
              c.accent,
              c.accentSoft,
              c.textPrimary,
            ],
            stops: <double>[at(-0.30), at(-0.10), at(0.10), at(0.30)],
          ).createShader(bounds);
        },
        child: child,
      ),
      child: text,
    );
  }
}

/// Softens the two edges where the scroll view cuts the page.
///
/// A card that runs past the bottom of the window used to end on a hard
/// horizontal line, drawn right across the screen. Here the content dissolves
/// into the room over the last few pixels instead. The top edge is left alone
/// until the page is actually scrolled, so nothing looks dimmed at rest.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.topFade, required this.child});

  final ValueListenable<double> topFade;
  final Widget child;

  /// The fades are small on purpose: enough to lose the edge, not so much
  /// that a figure near the bottom of the page reads as faint.
  static const double _bottomDepth = 30;
  static const double _topDepth = 18;

  static const List<Color> _stopColours = <Color>[
    Color(0x00FFFFFF),
    Color(0xFFFFFFFF),
    Color(0xFFFFFFFF),
    Color(0x00FFFFFF),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: topFade,
      builder: (BuildContext context, double t, Widget? child) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (Rect bounds) {
          final double height = bounds.height;
          // Too short to fade without swallowing the content itself.
          if (height <= (_bottomDepth + _topDepth) * 2) {
            return const LinearGradient(
              colors: <Color>[Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
            ).createShader(bounds);
          }
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _stopColours,
            stops: <double>[
              0,
              (_topDepth * t) / height,
              1 - _bottomDepth / height,
              1,
            ],
          ).createShader(bounds);
        },
        child: child,
      ),
      child: child,
    );
  }
}
