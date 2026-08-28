import 'package:flutter/foundation.dart';

import '../../core/platform/tempo_platform.dart';
import 'macos_usage_tracker.dart';
import 'windows_usage_tracker.dart';

/// The application in front of the user right now.
@immutable
class ActiveApplication {
  const ActiveApplication({
    required this.id,
    required this.name,
    this.executablePath,
  });

  /// The stable identity usage is grouped by: the executable name on Windows,
  /// the bundle identifier on macOS. Every window of an application shares it,
  /// so one application never becomes several.
  final String id;

  /// What the person calls it — "Google Chrome", not "chrome.exe".
  final String name;

  final String? executablePath;

  @override
  bool operator ==(Object other) =>
      other is ActiveApplication && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Something the machine did that measurement has to respect.
enum SystemEvent {
  /// The machine is going to sleep.
  sleep,

  /// The machine woke up.
  wake,

  /// The screen was locked, or the session switched away.
  lock,

  /// The screen was unlocked.
  unlock,
}

/// Whether the system will let Tempo see what it needs.
enum TrackingPermission {
  /// Nothing to ask for on this system.
  notRequired,

  granted,
  denied,

  /// This platform has no implementation.
  unsupported,
}

/// What every platform implementation has to answer.
///
/// Windows and macOS reach this differently and are honest about it: the
/// interface is deliberately small, and anything one system cannot do is said
/// plainly rather than faked.
abstract class UsageTrackingPlatform {
  const UsageTrackingPlatform();

  /// The implementation for the machine this is running on.
  factory UsageTrackingPlatform.forThisDevice() {
    if (TempoPlatform.isWindows) {
      return WindowsUsageTracker();
    }
    if (TempoPlatform.isMacOS) {
      return MacOsUsageTracker();
    }
    return const UnsupportedUsageTracker();
  }

  /// Stored on every session, so a database moved between machines still says
  /// where each session came from.
  String get platformName;

  bool get isSupported;

  /// One sentence for Settings about what this system lets Tempo measure.
  String get capabilityNote;

  /// The frontmost application, or null when there is none — an empty desktop,
  /// a locked screen, or a window Tempo cannot identify.
  Future<ActiveApplication?> activeApplication();

  /// Sleep, wake and lock as the system reports them.
  ///
  /// The engine does not depend on these: it detects the same conditions from
  /// its own clocks. Where a system does publish them, they arrive at once
  /// rather than at the next sample.
  Stream<SystemEvent> get systemEvents => const Stream<SystemEvent>.empty();

  /// How long the machine has gone without keyboard or mouse input.
  Future<Duration> idleTime();

  Future<TrackingPermission> permission();

  /// Asks the system for what is missing. Returns whether tracking can now
  /// proceed.
  Future<bool> requestPermission();
}

/// Used anywhere Tempo runs but cannot measure — Linux today.
class UnsupportedUsageTracker extends UsageTrackingPlatform {
  const UnsupportedUsageTracker();

  @override
  String get platformName => 'unsupported';

  @override
  bool get isSupported => false;

  @override
  String get capabilityNote =>
      'Tempo measures application usage on Windows and macOS. On this system '
      'it will not record anything.';

  @override
  Future<ActiveApplication?> activeApplication() async => null;

  @override
  Future<Duration> idleTime() async => Duration.zero;

  @override
  Future<TrackingPermission> permission() async =>
      TrackingPermission.unsupported;

  @override
  Future<bool> requestPermission() async => false;
}
