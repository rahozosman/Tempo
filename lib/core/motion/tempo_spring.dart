import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'tempo_motion.dart';

/// Springs, for the things a hand touches.
///
/// A timed curve always takes the same time whatever it is doing, and cannot be
/// interrupted honestly: change the target halfway and it restarts. A spring
/// carries its velocity, so a pill chased across the sidebar keeps its
/// momentum, and nothing ever snaps back to zero to start again.
///
/// None of these overshoot much — Tempo settles, it does not bounce.
class TempoSpring {
  const TempoSpring._();

  /// Selection indicators and anything that must arrive quickly.
  static const SpringDescription snap = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 34,
  );

  /// The default: a considered move that comes to rest without a wobble.
  static const SpringDescription settle = SpringDescription(
    mass: 1,
    stiffness: 240,
    damping: 28,
  );

  /// Hover and press, where the distance is small and the response should be
  /// immediate.
  static const SpringDescription touch = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 30,
  );
}

/// Drives a single number with a spring, re-aiming mid-flight.
///
/// Give it a target; it moves there from wherever it is, at whatever speed it
/// already had. Under the system's reduced-motion setting it simply is the
/// value, with no movement at all.
class SpringValue extends StatefulWidget {
  const SpringValue({
    super.key,
    required this.value,
    required this.builder,
    this.spring = TempoSpring.settle,
    this.child,
  });

  final double value;
  final SpringDescription spring;
  final Widget Function(BuildContext context, double value, Widget? child)
  builder;
  final Widget? child;

  @override
  State<SpringValue> createState() => _SpringValueState();
}

class _SpringValueState extends State<SpringValue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: widget.value,
  );

  @override
  void didUpdateWidget(covariant SpringValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _aim();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TempoMotion.reduced(context)) {
      _controller
        ..stop()
        ..value = widget.value;
    }
  }

  void _aim() {
    if (TempoMotion.reduced(context)) {
      _controller
        ..stop()
        ..value = widget.value;
      return;
    }
    // The current velocity is carried into the new simulation: that is the
    // whole point — an interrupted move continues rather than restarts.
    _controller.animateWith(
      SpringSimulation(
        widget.spring,
        _controller.value,
        widget.value,
        _controller.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) =>
          widget.builder(context, _controller.value, child),
      child: widget.child,
    );
  }
}
