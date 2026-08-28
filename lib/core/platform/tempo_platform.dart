import 'dart:io' show Platform;

/// Platform checks used to keep desktop-only calls off other targets and to
/// apply the small platform refinements described in the design system.
class TempoPlatform {
  const TempoPlatform._();

  static bool get isMacOS => Platform.isMacOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;
  static bool get isDesktop => isMacOS || isWindows || isLinux;

  /// macOS draws its own window buttons; Windows gets Tempo caption buttons.
  static bool get drawsOwnCaptionButtons => isWindows || isLinux;
}
