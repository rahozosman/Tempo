import 'package:flutter/foundation.dart';

/// One unbroken stretch in one application.
///
/// A session never crosses midnight: the tracking engine closes the one it is
/// holding at the day boundary and opens a new one, so every session belongs
/// to exactly one calendar day and day totals never need a split.
@immutable
class UsageSession {
  const UsageSession({
    required this.applicationId,
    required this.applicationName,
    required this.start,
    required this.end,
    required this.platform,
    this.id,
  });

  /// Set once the row exists.
  final int? id;

  /// The platform identity: the executable name on Windows, the bundle
  /// identifier on macOS. Usage is grouped by this, so several windows of one
  /// application stay one application.
  final String applicationId;

  final String applicationName;

  final DateTime start;
  final DateTime end;

  /// 'windows' or 'macos', kept so a database moved between machines still
  /// says where each session came from.
  final String platform;

  Duration get duration => end.difference(start);

  /// Local midnight of the day this session belongs to.
  DateTime get day => DateTime(start.year, start.month, start.day);

  UsageSession copyWith({DateTime? end}) => UsageSession(
    id: id,
    applicationId: applicationId,
    applicationName: applicationName,
    start: start,
    end: end ?? this.end,
    platform: platform,
  );
}
