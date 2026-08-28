import 'package:flutter/foundation.dart';

/// A block of deliberate work: how long it was meant to run, how long it
/// actually ran, and how much of that stayed in work applications.
///
/// The focused figure is not an estimate. When a block ends, Tempo reads the
/// sessions it actually recorded inside the window and adds up the ones whose
/// application belongs to a category that counts as focus.
@immutable
class FocusBlock {
  const FocusBlock({
    required this.start,
    required this.end,
    required this.target,
    required this.focused,
    this.id,
  });

  final int? id;
  final DateTime start;
  final DateTime end;

  /// What was asked for.
  final Duration target;

  /// What was measured inside the block, in focus applications.
  final Duration focused;

  Duration get length => end.difference(start);

  DateTime get day => DateTime(start.year, start.month, start.day);

  /// Whether the block ran its full length rather than being stopped early.
  bool get completed => length >= target - const Duration(seconds: 5);

  /// How much of the block was spent focused, 0 to 1.
  double get share => length.inSeconds <= 0
      ? 0
      : (focused.inSeconds / length.inSeconds).clamp(0.0, 1.0);
}
