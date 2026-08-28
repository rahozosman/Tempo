import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tempo_motion.dart';
import 'tempo_spring.dart';

/// Fade and rise. The single entrance used by headers, cards and rows.
///
/// Pass [index] to stagger a group: each step waits one [TempoDuration.stagger]
/// longer than the last.
class TempoEntrance extends StatefulWidget {
  const TempoEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.rise = 14,
    this.duration = TempoDuration.slow,
    this.delay = Duration.zero,
  });

  final Widget child;
  final int index;
  final double rise;
  final Duration duration;
  final Duration delay;

  @override
  State<TempoEntrance> createState() => _TempoEntranceState();
}

class _TempoEntranceState extends State<TempoEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final CurvedAnimation _animation = CurvedAnimation(
    parent: _controller,
    curve: TempoCurve.entrance,
  );

  /// How far below the fold a widget may be and still count as arriving.
  static const double _threshold = 0.94;

  Timer? _timer;
  ScrollPosition? _position;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listenToScroll();
    if (_started) {
      return;
    }
    _started = true;
    if (TempoMotion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    // Anything already on screen arrives on the page's own rhythm; anything
    // below the fold waits until it is scrolled to, so a long page reveals
    // itself as it is read rather than animating where nobody can see it.
    if (_isVisible()) {
      _begin(widget.delay + TempoDuration.stagger * widget.index);
    }
  }

  void _listenToScroll() {
    final ScrollPosition? position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _position)) {
      return;
    }
    _position?.removeListener(_onScroll);
    _position = position;
    _position?.addListener(_onScroll);
  }

  void _onScroll() {
    if (_controller.isAnimating || _controller.value > 0) {
      return;
    }
    if (_isVisible()) {
      _begin(Duration.zero);
    }
  }

  /// True when this widget's top edge is inside — or nearly inside — the
  /// window. Off-screen widgets are left alone.
  bool _isVisible() {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.attached) {
      // No box yet: assume it is on screen rather than never animating.
      return true;
    }
    // localToGlobal answers in the window's own space, so the window is what
    // it must be measured against. MediaQuery would be the *scaled* canvas
    // once the display size is anything but 100%, and the two would disagree —
    // leaving everything below the fold invisible for ever.
    final double top = object.localToGlobal(Offset.zero).dy;
    final ui.FlutterView view = View.of(context);
    final double height = view.physicalSize.height / view.devicePixelRatio;
    return height <= 0 || top < height * _threshold;
  }

  void _begin(Duration wait) {
    if (_controller.value > 0 || _controller.isAnimating) {
      return;
    }
    _position?.removeListener(_onScroll);
    if (wait == Duration.zero) {
      _controller.forward();
      return;
    }
    _timer?.cancel();
    _timer = Timer(wait, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _position?.removeListener(_onScroll);
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) {
        final double t = _animation.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, widget.rise * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Pointer-aware container. Rebuilds its [builder] with the hover state and
/// optionally handles taps, so hover styling never needs a Material ink well.
class HoverBuilder extends StatefulWidget {
  const HoverBuilder({
    super.key,
    required this.builder,
    this.onTap,
    this.cursor,
    this.enabled = true,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final MouseCursor? cursor;
  final bool enabled;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;

  void _set(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool interactive = widget.enabled && widget.onTap != null;
    Widget child = widget.builder(context, _hovered && widget.enabled);
    if (interactive) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: child,
      );
    }
    return MouseRegion(
      cursor:
          widget.cursor ??
          (interactive ? SystemMouseCursors.click : MouseCursor.defer),
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: child,
    );
  }
}

/// Press feedback: a small, quick scale down. Used by every Tempo button.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      child: SpringValue(
        value: _pressed ? widget.scale : 1,
        spring: TempoSpring.touch,
        builder: (BuildContext context, double scale, Widget? child) =>
            Transform.scale(scale: scale, child: child),
        child: widget.child,
      ),
    );
  }
}

/// The page transition for the shell: a calm cross fade with a short rise.
class TempoPageSwitcher extends StatefulWidget {
  const TempoPageSwitcher({super.key, required this.child, this.order = 0});

  final Widget child;

  /// Where the page sits in the sidebar. The switcher only uses it to know
  /// which way the move went, so the new page arrives from the direction it
  /// was chosen from.
  final int order;

  @override
  State<TempoPageSwitcher> createState() => _TempoPageSwitcherState();
}

class _TempoPageSwitcherState extends State<TempoPageSwitcher> {
  /// True when the last move went down the sidebar. A rebuild that changes
  /// nothing keeps the direction it had.
  bool _forward = true;

  @override
  void didUpdateWidget(covariant TempoPageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.order != oldWidget.order) {
      _forward = widget.order > oldWidget.order;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Distance is tiny on purpose: the page should feel handed over, not
    // thrown. Depth does the rest — the leaving page falls a little behind
    // while the arriving one settles forward.
    final double travel = _forward ? 0.020 : -0.020;
    final Key? arriving = widget.child.key;

    return AnimatedSwitcher(
      duration: TempoMotion.of(context, TempoDuration.page),
      reverseDuration: TempoMotion.of(context, TempoDuration.quick),
      switchInCurve: TempoCurve.entrance,
      switchOutCurve: TempoCurve.exit,
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        fit: StackFit.expand,
        alignment: Alignment.topLeft,
        children: <Widget>[...previous, ?current],
      ),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final bool incoming = child.key == arriving;
        final double from = incoming ? travel : -travel * 0.6;
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, from),
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: incoming ? 0.988 : 1.006,
                end: 1,
              ).animate(animation),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Draws an accent ring around a control while it holds *keyboard* focus.
///
/// Clicking a control never draws the ring: like macOS, the ring only appears
/// once someone is moving through the interface with the keyboard. Enter and
/// Space activate whatever the ring is around.
class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.child,
    required this.radius,
    this.onActivate,
    this.enabled = true,
    this.inset = -3,
  });

  final Widget child;

  /// Corner radius of the control underneath.
  final double radius;

  final VoidCallback? onActivate;
  final bool enabled;

  /// How far the ring sits outside the control. Negative is outside.
  final double inset;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  void _showHighlight(bool value) {
    if (_focused == value || !mounted) {
      return;
    }
    setState(() => _focused = value);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return FocusableActionDetector(
      enabled: widget.enabled,
      onShowFocusHighlight: _showHighlight,
      mouseCursor: MouseCursor.defer,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            widget.onActivate?.call();
            return null;
          },
        ),
      },
      child: Stack(
        clipBehavior: Clip.none,
        // Passthrough, so a control that was stretched by its parent keeps
        // the height it had before the ring wrapped it.
        fit: StackFit.passthrough,
        children: <Widget>[
          widget.child,
          Positioned(
            left: widget.inset,
            top: widget.inset,
            right: widget.inset,
            bottom: widget.inset,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _focused ? 1 : 0,
                duration: TempoMotion.of(context, TempoDuration.quick),
                curve: TempoCurve.gentle,
                child: CustomPaint(
                  painter: _FocusRingPainter(
                    color: accent,
                    radius: widget.radius - widget.inset,
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

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final RRect ring = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      Radius.circular(radius),
    );
    // A wide, soft halo under a crisp hairline: the ring reads on glass
    // without turning into a hard outline.
    canvas.drawRRect(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = color.withValues(alpha: 0.22),
    );
    canvas.drawRRect(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.color != color || old.radius != radius;
}
