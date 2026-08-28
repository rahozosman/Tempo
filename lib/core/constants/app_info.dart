/// Static product facts. No network, no analytics, no account.
class AppInfo {
  const AppInfo._();

  static const String name = 'Tempo';
  static const String tagline = 'Screen time, measured beautifully';
  static const String version = '1.0.0';
  static const String privacyLine = 'Private. Everything stays on this device.';

  /// Who made it. Shown in Settings and, quietly, at the foot of every screen.
  static const String developer = 'Rahoz Osman';
  static const String developerEmail = 'hozahoza2001@gmail.com';

  /// Where new versions are published. Tempo never requests this itself: the
  /// About section opens it in your browser, and only when you ask.
  static const String releasesUrl = 'https://github.com/tempo-app/tempo/releases';
}
