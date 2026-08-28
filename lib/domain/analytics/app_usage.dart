import 'package:flutter/foundation.dart';

/// Time spent in one application over some period.
///
/// [id] is the platform identity — the executable name on Windows, the bundle
/// identifier on macOS — and is what usage is grouped by, so several windows of
/// the same application stay one entry.
@immutable
class AppUsage {
  const AppUsage({
    required this.id,
    required this.name,
    required this.duration,
    this.previous,
  });

  final String id;
  final String name;
  final Duration duration;

  /// The same application over the previous, equal-length period. Null when
  /// there is nothing to compare against.
  final Duration? previous;

  double shareOf(Duration total) =>
      total.inSeconds <= 0 ? 0 : duration.inSeconds / total.inSeconds;

  /// Relative change against [previous], or null when a comparison would be
  /// meaningless.
  double? get change {
    final Duration? before = previous;
    if (before == null || before.inSeconds <= 0) {
      return null;
    }
    return (duration.inSeconds - before.inSeconds) / before.inSeconds;
  }

  AppUsage plus(Duration extra) =>
      AppUsage(id: id, name: name, duration: duration + extra, previous: previous);
}
