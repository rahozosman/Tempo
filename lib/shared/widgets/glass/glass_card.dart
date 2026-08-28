import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show PointerEnterEvent, PointerEvent;
import 'package:flutter/material.dart';

import '../../../core/motion/tempo_animations.dart';
import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_theme.dart';
import 'glass_surface.dart';

/// A card's pointer state, published to its own content.
///
/// Lets a glyph tile or a chevron inside a card answer the same hover the card
/// answers, without every card having to thread a flag through its children.
class CardHoverScope extends InheritedWidget {
  const CardHoverScope({
    super.key,
    required this.hovered,
    required this.pressed,
    required super.child,
  });

  final bool hovered;
  final bool pressed;

  static bool hoveredOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardHoverScope>()?.hovered ??
      false;

  static bool pressedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardHoverScope>()?.pressed ??
      false;

  @override
  bool updateShouldNotify(CardHoverScope oldWidget) =>
      oldWidget.hovered != hovered || oldWidget.pressed != pressed;
}

/// A content card. Every card answers the pointer: the edge brightens, the
/// depth deepens and a soft accent sheen follows the cursor across the glass.
/// A tappable card answers a little louder, lifts, sinks under a press and
/// takes a focus ring from the keyboard; nothing scales, nothing bounces.
class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TempoSpace.lg),
    this.onTap,
    this.radius = TempoRadius.lg,
    this.blur = 0,
    this.hoverLift = true,
    this.hoverGlow = true,
    this.semanticLabel,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final double blur;

  /// Whether the card rises a little under the pointer. Large chrome cards
  /// keep their place and answer with light alone.
  final bool hoverLift;

  /// Whether the cursor carries a soft accent sheen across the surface.
  final bool hoverGlow;

  final String? semanticLabel;
  final double? width;
  final double? height;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  /// Where the pointer sits inside the card, as an alignment. Kept out of
  /// [setState] so tracking the cursor never rebuilds the card's content.
  final ValueNotifier<Alignment> _pointer = ValueNotifier<Alignment>(
    Alignment.center,
  );

  /// Drives the glint that crosses the glass. It turns only while the pointer
  /// is on the card, so a page of cards costs nothing at rest.
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );

  bool _hovered = false;
  bool _pressed = false;

  @override
  void dispose() {
    _shine.dispose();
    _pointer.dispose();
    super.dispose();
  }

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    if (value && !TempoMotion.reduced(context) && !_shine.isAnimating) {
      _shine.repeat();
    }
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  void _track(PointerEvent event) {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize) {
      return;
    }
    final Size size = object.size;
    if (size.isEmpty) {
      return;
    }
    final Offset local = object.globalToLocal(event.position);
    _pointer.value = Alignment(
      (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final TempoTheme theme = context.tempo;
    final bool reduced = TempoMotion.reduced(context);
    final bool tappable = widget.onTap != null;

    // How loudly this card answers: a tappable card fully, a plain one
    // quietly, so a page of panels never turns into a light show.
    final double weight = tappable ? 1.0 : 0.55;
    final bool glow = widget.hoverGlow && !reduced;

    final Color fill = _hovered
        ? Color.lerp(c.glassFill, c.glassFillStrong, weight)!
        : c.glassFill;

    // Under the pointer the card drops its shadow entirely and answers with
    // light alone: the travelling edge is the whole answer, with nothing cast
    // on the page behind it.
    final List<BoxShadow> shadow = (_hovered || _pressed)
        ? const <BoxShadow>[]
        : theme.cardShadow;
    final double lift = reduced
        ? 0
        : (_pressed
              ? 1
              : (_hovered && widget.hoverLift ? (tappable ? -6 : -4) : 0));

    Widget card = AnimatedContainer(
      duration: TempoMotion.of(
        context,
        _pressed ? TempoDuration.instant : TempoDuration.base,
      ),
      curve: TempoCurve.gentle,
      transform: Matrix4.translationValues(0, lift, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: shadow,
      ),
      child: GlassSurface(
        radius: widget.radius,
        blur: widget.blur,
        padding: widget.padding,
        width: widget.width,
        height: widget.height,
        shadows: const <BoxShadow>[],
        fill: fill,
        // No hairline: the coloured edge alone draws the outline, and comes
        // forward under the pointer.
        edge: _hovered ? 0.95 : 0.5,
        overlay: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (glow)
              _HoverSheen(
                pointer: _pointer,
                visible: _hovered,
                wash: c.accent.withValues(alpha: tappable ? 0.14 : 0.08),
              ),
            if (!reduced)
              _HoverShine(
                shine: _shine,
                visible: _hovered,
                strength: tappable ? 1.0 : 0.8,
                onSettled: () {
                  if (!_hovered && _shine.isAnimating) {
                    _shine.stop();
                  }
                },
              ),
          ],
        ),
        child: CardHoverScope(
          hovered: _hovered,
          pressed: _pressed,
          child: widget.child,
        ),
      ),
    );

    if (tappable) {
      card = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (TapDownDetails _) => _setPressed(true),
        onTapUp: (TapUpDetails _) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: card,
      );
    }

    card = MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (PointerEnterEvent event) {
        _track(event);
        _setHovered(true);
      },
      onHover: glow ? _track : null,
      onExit: (_) {
        _setPressed(false);
        _setHovered(false);
      },
      child: card,
    );

    if (tappable) {
      card = FocusRing(
        radius: widget.radius,
        onActivate: widget.onTap,
        child: card,
      );
    }

    if (widget.semanticLabel == null) {
      return card;
    }
    return Semantics(
      label: widget.semanticLabel,
      button: tappable,
      container: true,
      child: card,
    );
  }
}

/// The glint: one soft band of light crossing the glass from the bottom-left
/// corner to the top-right one while the pointer is on the card, then again
/// after a pause.
///
/// It rides inside the card's own clip, so it can only ever be the card's
/// shape: a bright core with the product's violet trailing it, crossing
/// slowly enough to read as the card being polished rather than lit.
class _HoverShine extends StatelessWidget {
  const _HoverShine({
    required this.shine,
    required this.visible,
    required this.strength,
    required this.onSettled,
  });

  final Animation<double> shine;
  final bool visible;

  /// How loudly this card answers: a tappable one takes the full glint.
  final double strength;

  /// Called once the glint has faded out, so nothing turns at rest.
  final VoidCallback onSettled;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final bool isDark = context.tempo.isDark;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: TempoMotion.of(context, TempoDuration.base),
      curve: TempoCurve.gentle,
      onEnd: onSettled,
      child: AnimatedBuilder(
        animation: shine,
        builder: (BuildContext context, Widget? child) => CustomPaint(
          painter: _ShinePainter(
            t: shine.value,
            // White is the light on dark glass; on a pale card the same
            // sweep has to be the accent, or it would not be there at all.
            highlight: isDark ? const Color(0xFFFFFFFF) : c.accent,
            tint: c.accentSoft,
            strength: strength * (isDark ? 1.0 : 0.8),
          ),
        ),
      ),
    );
  }
}

class _ShinePainter extends CustomPainter {
  const _ShinePainter({
    required this.t,
    required this.highlight,
    required this.tint,
    required this.strength,
  });

  /// Where the band has got to on its way across, 0 to 1.
  final double t;

  /// The light itself, and the colour trailing it.
  final Color highlight;
  final Color tint;

  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final Rect bounds = Offset.zero & size;

    // The band starts and finishes well off the card, so each pass ends in a
    // rest rather than running straight into the next one.
    final double head = -0.7 + 2.4 * t;
    double at(double offset) => (head + offset).clamp(0.0, 1.0);

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: <Color>[
            highlight.withValues(alpha: 0),
            highlight.withValues(alpha: 0.05 * strength),
            highlight.withValues(alpha: 0.14 * strength),
            tint.withValues(alpha: 0.09 * strength),
            tint.withValues(alpha: 0),
          ],
          stops: <double>[at(-0.32), at(-0.13), at(0.0), at(0.15), at(0.34)],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_ShinePainter old) =>
      old.t != t ||
      old.strength != strength ||
      old.highlight != highlight ||
      old.tint != tint;
}

/// The pointer sheen: a wide, soft accent halo centred on the cursor, fading
/// in and out with the hover rather than blinking on.
///
/// Only the halo. The card's outline is left to the travelling light, so
/// nothing draws a standing line along an edge under the pointer.
class _HoverSheen extends StatelessWidget {
  const _HoverSheen({
    required this.pointer,
    required this.visible,
    required this.wash,
  });

  final ValueListenable<Alignment> pointer;
  final bool visible;
  final Color wash;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: TempoMotion.of(context, TempoDuration.base),
      curve: TempoCurve.gentle,
      child: ValueListenableBuilder<Alignment>(
        valueListenable: pointer,
        builder: (BuildContext context, Alignment value, Widget? child) =>
            CustomPaint(
              painter: _HoverSheenPainter(pointer: value, wash: wash),
            ),
      ),
    );
  }
}

/// Paints the halo the cursor carries across the glass, and nothing else.
class _HoverSheenPainter extends CustomPainter {
  const _HoverSheenPainter({required this.pointer, required this.wash});

  final Alignment pointer;
  final Color wash;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final Rect bounds = Offset.zero & size;
    final Offset centre = pointer.withinRect(bounds);

    canvas.drawRect(
      bounds,
      Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[wash, wash.withValues(alpha: 0)],
            ).createShader(
              Rect.fromCircle(center: centre, radius: size.shortestSide),
            ),
    );
  }

  @override
  bool shouldRepaint(_HoverSheenPainter old) =>
      old.pointer != pointer || old.wash != wash;
}

/// A large chrome panel. This is the one place a real backdrop blur is used,
/// because there are only ever a handful on screen.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(TempoSpace.xl),
    this.radius = TempoRadius.xl,
    this.blur = 24,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: radius,
      blur: blur,
      padding: padding,
      width: width,
      height: height,
      shadows: context.tempo.panelShadow,
      child: child,
    );
  }
}
