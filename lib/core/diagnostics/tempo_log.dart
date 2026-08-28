import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A small rolling log beside the database.
///
/// Tempo's riskiest code — the Win32 calls, the macOS channel, the tray — fails
/// quietly by nature: a missed foreground reading looks exactly like a quiet
/// afternoon. This is where those failures are written down so they can be read
/// afterwards, without ever interrupting what the app is doing.
///
/// It holds no usage data: only what went wrong, and when.
class TempoLog {
  const TempoLog._();

  static const String fileName = 'tempo.log';
  static const int maxBytes = 256 * 1024;

  static File? _file;
  static Future<void> _queue = Future<void>.value();

  static String? get path => _file?.path;

  /// Opens the log, rotating it when it has grown past [maxBytes]. Any failure
  /// leaves logging switched off rather than stopping the app.
  static Future<void> open() async {
    try {
      final Directory directory = await getApplicationSupportDirectory();
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }
      final File file = File(p.join(directory.path, fileName));
      if (file.existsSync() && await file.length() > maxBytes) {
        final File previous = File('${file.path}.1');
        if (previous.existsSync()) {
          await previous.delete();
        }
        await file.rename(previous.path);
      }
      _file = File(p.join(directory.path, fileName));
      note('Tempo ${DateTime.now()} · log opened');
    } on Object catch (error) {
      debugPrint('Tempo · logging unavailable · $error');
    }
  }

  static void note(String message) => _append('NOTE ', message);

  static void error(String message, [Object? error, StackTrace? stack]) {
    final StringBuffer buffer = StringBuffer(message);
    if (error != null) {
      buffer.write(' · $error');
    }
    _append('ERROR', buffer.toString());
    if (stack != null && kDebugMode) {
      debugPrintStack(stackTrace: stack);
    }
  }

  static void _append(String level, String message) {
    debugPrint('Tempo · $message');
    final File? file = _file;
    if (file == null) {
      return;
    }
    final String line =
        '${DateTime.now().toIso8601String()}  $level  $message\n';
    // Writes are chained so two failures at once cannot interleave, and a
    // failing log never becomes a failing app.
    _queue = _queue.then((_) async {
      try {
        await file.writeAsString(line, mode: FileMode.append);
      } on Object catch (_) {
        // A log that cannot be written must never become a crash.
      }
    });
  }
}
