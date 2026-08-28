import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Everything that leaves the app is behind one of these calls, and every one
/// of them is started by the person using it.
class ShareService {
  const ShareService._();

  /// Puts the report on the clipboard.
  static Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  /// Opens WhatsApp — the desktop app if it is installed, otherwise the web
  /// client — with the report already written. Nothing is sent: the person
  /// chooses the recipient and presses send themselves.
  static Future<bool> openWhatsApp(String text) async {
    final Uri uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(text)}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Writes the report text next to the user's other downloads.
  static Future<String?> saveText(String text, String fileName) =>
      // The report carries typographic characters, so it is written as UTF-8
      // rather than raw code units.
      _write(fileName, utf8.encode(text));

  /// Renders the share card at three times its logical size and writes a PNG.
  static Future<String?> saveImage(GlobalKey boundaryKey, String fileName) async {
    final RenderObject? object = boundaryKey.currentContext
        ?.findRenderObject();
    if (object is! RenderRepaintBoundary) {
      return null;
    }
    final ui.Image image = await object.toImage(pixelRatio: 3);
    try {
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (data == null) {
        return null;
      }
      return _write(fileName, data.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  /// The folder saved files land in: Downloads when it exists, the home folder
  /// otherwise.
  static String? saveFolder() {
    final Map<String, String> environment = Platform.environment;
    final String? home = Platform.isWindows
        ? environment['USERPROFILE']
        : environment['HOME'];
    if (home == null || home.isEmpty) {
      return null;
    }
    final Directory downloads = Directory(
      '$home${Platform.pathSeparator}Downloads',
    );
    return downloads.existsSync() ? downloads.path : home;
  }

  static Future<String?> _write(String fileName, List<int> bytes) async {
    final String? folder = saveFolder();
    if (folder == null) {
      return null;
    }
    final File file = File('$folder${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
