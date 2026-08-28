import 'package:flutter/material.dart';

import '../../core/motion/tempo_motion.dart';
import '../../core/theme/tempo_theme.dart';
import 'empty_state.dart';
import 'tempo_icon.dart';
import 'tempo_mark.dart';

/// The waiting state. The Tempo mark breathes; nothing spins.
class PageLoading extends StatefulWidget {
  const PageLoading({super.key, this.label});

  final String? label;

  @override
  State<PageLoading> createState() => _PageLoadingState();
}

class _PageLoadingState extends State<PageLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TempoDuration.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TempoMotion.reduced(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) => Opacity(
              opacity: 0.45 + 0.55 * Curves.easeInOut.transform(_controller.value),
              child: child,
            ),
            child: const TempoMark(size: 42),
          ),
          if (widget.label != null) ...<Widget>[
            const SizedBox(height: 18),
            Text(widget.label!, style: context.typo.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// The failure state. Users see a plain sentence and what to do next; the
/// technical detail goes to the debug console instead of the screen.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.title,
    required this.message,
    this.detail,
  });

  final String title;
  final String message;
  final Object? detail;

  @override
  Widget build(BuildContext context) {
    if (detail != null) {
      debugPrint('Tempo · $title · $detail');
    }
    return EmptyState(
      glyph: TempoGlyph.info,
      tone: context.colors.danger,
      title: title,
      message: message,
    );
  }
}
