import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/motion/tempo_motion.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import 'glass/glass_surface.dart';
import 'tempo_icon.dart';

/// The quiet confirmation that something happened — a report copied, a file
/// written. It rises in the bottom corner, waits, and leaves.
class TempoToast {
  const TempoToast._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    TempoGlyph glyph = TempoGlyph.sparkle,
    bool isError = false,
  }) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    _dismiss();

    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) => Positioned(
        right: TempoSpace.lg,
        bottom: TempoSpace.lg,
        child: _ToastCard(
          message: message,
          glyph: glyph,
          isError: isError,
        ),
      ),
    );
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(milliseconds: 2800), _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.message,
    required this.glyph,
    required this.isError,
  });

  final String message;
  final TempoGlyph glyph;
  final bool isError;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TempoDuration.base,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final Color tone = widget.isError ? c.danger : c.accentSoft;
    final CurvedAnimation curved = CurvedAnimation(
      parent: _controller,
      curve: TempoCurve.entrance,
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: curved.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - curved.value)),
          child: child,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassSurface(
            radius: TempoRadius.md,
            fill: c.surfaceElevated.withValues(alpha: 0.97),
            padding: const EdgeInsets.symmetric(
              horizontal: TempoSpace.md,
              vertical: TempoSpace.sm + 2,
            ),
            shadows: context.tempo.panelShadow,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TempoIcon(widget.glyph, size: 17, color: tone),
                const SizedBox(width: TempoSpace.sm),
                Flexible(
                  child: Text(
                    widget.message,
                    style: context.typo.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
