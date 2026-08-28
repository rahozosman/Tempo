import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/diagnostics/tempo_log.dart';
import 'usage_tracking_platform.dart';

/// macOS foreground tracking.
///
/// AppKit already publishes which application is frontmost, so Tempo asks it
/// through a method channel rather than inspecting anything itself. Usage is
/// grouped by bundle identifier, which means every window of an application —
/// and an application relaunched later — stays one entry.
///
/// Two things are worth being straight about:
///
///  * Apple's own Screen Time data is private to the system. Tempo has no
///    access to it and does not pretend otherwise; what it reports is its own
///    measurement of the frontmost application.
///  * Watching the frontmost application and the idle timer needs no
///    Accessibility or Screen Recording permission, because neither reads
///    window contents, titles or documents.
class MacOsUsageTracker extends UsageTrackingPlatform {
  MacOsUsageTracker() {
    _channel.setMethodCallHandler(_onPlatformCall);
  }

  static const MethodChannel _channel = MethodChannel('tempo/usage_tracking');

  /// The sign-in and lock window is not an application anybody is using.
  static const Set<String> _notApplications = <String>{
    'com.apple.loginwindow',
    'com.apple.SecurityAgent',
  };

  final StreamController<SystemEvent> _events =
      StreamController<SystemEvent>.broadcast();

  @override
  Stream<SystemEvent> get systemEvents => _events.stream;

  @override
  String get platformName => 'macos';

  @override
  bool get isSupported => true;

  @override
  String get capabilityNote =>
      'macOS reports the frontmost application, when the machine sleeps or '
      'locks, and how long it has gone untouched — which is what Tempo '
      "measures. It has no access to Apple's own Screen Time data, and reads "
      'no window titles or documents.';

  @override
  Future<TrackingPermission> permission() async =>
      TrackingPermission.notRequired;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<ActiveApplication?> activeApplication() async {
    try {
      final Map<Object?, Object?>? payload = await _channel
          .invokeMapMethod<Object?, Object?>('activeApplication');
      if (payload == null) {
        return null;
      }
      final Object? id = payload['id'];
      final Object? name = payload['name'];
      if (id is! String || id.isEmpty || _notApplications.contains(id)) {
        return null;
      }
      return ActiveApplication(
        id: id,
        name: name is String && name.isNotEmpty ? name : id,
        executablePath: payload['path'] is String
            ? payload['path']! as String
            : null,
      );
    } on PlatformException catch (error) {
      TempoLog.error('foreground application unavailable · $error');
      return null;
    } on MissingPluginException {
      // The channel is registered by the app's own window, so this only
      // happens in a build without it.
      return null;
    }
  }

  @override
  Future<Duration> idleTime() async {
    try {
      final double? seconds = await _channel.invokeMethod<double>(
        'idleSeconds',
      );
      if (seconds == null || seconds.isNaN || seconds < 0) {
        return Duration.zero;
      }
      return Duration(milliseconds: (seconds * 1000).round());
    } on PlatformException catch (error) {
      TempoLog.error('idle time unavailable · $error');
      return Duration.zero;
    } on MissingPluginException {
      return Duration.zero;
    }
  }

  /// Sleep, wake and lock as macOS announces them, forwarded by the window.
  Future<Object?> _onPlatformCall(MethodCall call) async {
    if (call.method != 'systemEvent' || _events.isClosed) {
      return null;
    }
    final SystemEvent? event = switch (call.arguments) {
      'sleep' => SystemEvent.sleep,
      'wake' => SystemEvent.wake,
      'lock' => SystemEvent.lock,
      'unlock' => SystemEvent.unlock,
      _ => null,
    };
    if (event != null) {
      _events.add(event);
    }
    return null;
  }
}
