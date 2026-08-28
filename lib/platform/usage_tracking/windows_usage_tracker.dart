import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../../core/diagnostics/tempo_log.dart';
import 'usage_tracking_platform.dart';

/// Windows foreground tracking.
///
/// The chain is the one Windows itself uses: the foreground window, the thread
/// that owns it, the process behind that thread, and the executable behind the
/// process. Usage is grouped by the executable, so ten Chrome windows are one
/// application, and the name shown is the executable's own file description —
/// "Google Chrome" rather than "chrome.exe".
///
/// Nothing here reads window titles or document names. Tempo only needs to
/// know which application is in front.
class WindowsUsageTracker extends UsageTrackingPlatform {
  WindowsUsageTracker();

  /// Executable path to display name. Reading version information touches the
  /// disk, so each executable is resolved once per run.
  final Map<String, String> _names = <String, String>{};

  static const int _pathBufferLength = 1024;

  /// The lock and sign-in screens run as ordinary processes. Nobody is using
  /// an application while they are in front, so they are not counted — which
  /// is also how Windows locking is handled, since it publishes no event
  /// Tempo can listen to from here.
  static const Set<String> _notApplications = <String>{
    'lockapp.exe',
    'logonui.exe',
  };

  @override
  String get platformName => 'windows';

  @override
  bool get isSupported => true;

  @override
  String get capabilityNote =>
      'Windows lets Tempo see which application is in front and how long the '
      'machine has gone untouched. No permission prompt is involved, and no '
      'window titles or document names are read.';

  /// Windows needs nothing granted for this.
  @override
  Future<TrackingPermission> permission() async =>
      TrackingPermission.notRequired;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<ActiveApplication?> activeApplication() async {
    try {
      final int window = GetForegroundWindow();
      if (window == 0) {
        return null;
      }

      final Pointer<Uint32> processId = calloc<Uint32>();
      try {
        GetWindowThreadProcessId(window, processId);
        final int pid = processId.value;
        if (pid == 0) {
          return null;
        }

        // Enough to read the executable path, and nothing more.
        final int process = OpenProcess(
          PROCESS_QUERY_LIMITED_INFORMATION,
          FALSE,
          pid,
        );
        if (process == 0) {
          return null;
        }
        try {
          final String? path = _executablePath(process);
          if (path == null || path.isEmpty) {
            return null;
          }
          final String file = _fileName(path);
          if (_notApplications.contains(file.toLowerCase())) {
            return null;
          }
          return ActiveApplication(
            id: file.toLowerCase(),
            name: _displayName(path, file),
            executablePath: path,
          );
        } finally {
          CloseHandle(process);
        }
      } finally {
        calloc.free(processId);
      }
    } on Object catch (error) {
      TempoLog.error('foreground application unavailable · $error');
      return null;
    }
  }

  @override
  Future<Duration> idleTime() async {
    final Pointer<LASTINPUTINFO> info = calloc<LASTINPUTINFO>();
    try {
      info.ref.cbSize = sizeOf<LASTINPUTINFO>();
      if (GetLastInputInfo(info) == 0) {
        return Duration.zero;
      }
      // Both values are 32-bit millisecond tick counts, so the subtraction has
      // to survive the counter wrapping about every 49 days.
      int elapsed = GetTickCount() - info.ref.dwTime;
      if (elapsed < 0) {
        elapsed += 0x100000000;
      }
      return Duration(milliseconds: elapsed);
    } on Object catch (error) {
      TempoLog.error('idle time unavailable · $error');
      return Duration.zero;
    } finally {
      calloc.free(info);
    }
  }

  String? _executablePath(int process) {
    final Pointer<Utf16> buffer = wsalloc(_pathBufferLength);
    final Pointer<Uint32> size = calloc<Uint32>()
      ..value = _pathBufferLength;
    try {
      if (QueryFullProcessImageName(process, 0, buffer, size) == 0) {
        return null;
      }
      return buffer.toDartString();
    } finally {
      calloc
        ..free(buffer)
        ..free(size);
    }
  }

  static String _fileName(String path) {
    final int slash = path.lastIndexOf(r'\');
    return slash == -1 ? path : path.substring(slash + 1);
  }

  String _displayName(String path, String file) =>
      _names[path] ??= _fileDescription(path) ?? _prettify(file);

  /// The executable's own description, which is what Windows shows in Task
  /// Manager. Any failure falls back to a tidied executable name rather than
  /// stopping the measurement.
  String? _fileDescription(String path) {
    final Pointer<Utf16> file = path.toNativeUtf16();
    Pointer<Uint8>? block;
    try {
      final int size = GetFileVersionInfoSize(file, nullptr);
      if (size == 0) {
        return null;
      }
      block = calloc<Uint8>(size);
      if (GetFileVersionInfo(file, 0, size, block.cast()) == 0) {
        return null;
      }

      // The description lives under the executable's own language and code
      // page, which the translation table names.
      final Pointer<Pointer<NativeType>> value = calloc<Pointer<NativeType>>();
      final Pointer<Uint32> length = calloc<Uint32>();
      final Pointer<Utf16> translationKey = r'\VarFileInfo\Translation'
          .toNativeUtf16();
      try {
        if (VerQueryValue(block.cast(), translationKey, value, length) == 0 ||
            length.value < 4) {
          return null;
        }
        final Pointer<Uint16> translation = value.value.cast<Uint16>();
        final String language = translation[0]
            .toRadixString(16)
            .padLeft(4, '0');
        final String codePage = translation[1]
            .toRadixString(16)
            .padLeft(4, '0');

        final Pointer<Utf16> descriptionKey =
            '\\StringFileInfo\\$language$codePage\\FileDescription'
                .toNativeUtf16();
        try {
          if (VerQueryValue(block.cast(), descriptionKey, value, length) == 0 ||
              length.value == 0) {
            return null;
          }
          final String description = value.value
              .cast<Utf16>()
              .toDartString()
              .trim();
          return description.isEmpty ? null : description;
        } finally {
          calloc.free(descriptionKey);
        }
      } finally {
        calloc
          ..free(translationKey)
          ..free(value)
          ..free(length);
      }
    } on Object catch (error) {
      TempoLog.error('could not read the name of $path · $error');
      return null;
    } finally {
      if (block != null) {
        calloc.free(block);
      }
      calloc.free(file);
    }
  }

  /// "some-app.exe" becomes "Some App", so a nameless executable still reads
  /// like an application.
  static String _prettify(String file) {
    String name = file;
    if (name.toLowerCase().endsWith('.exe')) {
      name = name.substring(0, name.length - 4);
    }
    name = name.replaceAll(RegExp(r'[_\-.]+'), ' ').trim();
    if (name.isEmpty) {
      return file;
    }
    return name
        .split(RegExp(r'\s+'))
        .map(
          (String word) => word.length <= 1
              ? word.toUpperCase()
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}
