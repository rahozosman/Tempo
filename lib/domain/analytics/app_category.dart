import 'package:flutter/material.dart';

import '../../core/theme/tempo_colors.dart';

/// What an application is for.
///
/// Seven buckets, deliberately few: enough to answer "where did the day go"
/// without turning the app into a taxonomy exercise. Every application starts
/// with a sensible guess and can be moved.
enum AppCategory {
  work,
  communication,
  browsing,
  media,
  games,
  system,
  other;

  static AppCategory fromName(String? name) => switch (name) {
    'work' => AppCategory.work,
    'communication' => AppCategory.communication,
    'browsing' => AppCategory.browsing,
    'media' => AppCategory.media,
    'games' => AppCategory.games,
    'system' => AppCategory.system,
    _ => AppCategory.other,
  };

  String get label => switch (this) {
    AppCategory.work => 'Work',
    AppCategory.communication => 'Communication',
    AppCategory.browsing => 'Browsing',
    AppCategory.media => 'Media',
    AppCategory.games => 'Games',
    AppCategory.system => 'System',
    AppCategory.other => 'Other',
  };

  /// Counted towards focused time. Communication is deliberately left out: it
  /// is work, but it is not the same as concentrating.
  bool get isFocus => this == AppCategory.work;

  Color tone(TempoColors c) => switch (this) {
    AppCategory.work => c.accent,
    AppCategory.communication => Color.lerp(c.accent, c.accentAlt, 0.55)!,
    AppCategory.browsing => c.accentAlt,
    AppCategory.media => c.accentSoft,
    AppCategory.games => Color.lerp(c.accentSoft, c.accent, 0.4)!,
    AppCategory.system => c.textSecondary,
    AppCategory.other => c.textTertiary,
  };
}

/// The starting guess for applications Tempo is likely to meet.
///
/// Keys are the identity usage is grouped by: the lowercase executable name on
/// Windows, the bundle identifier on macOS. Anything not listed starts as
/// [AppCategory.other] and can be set by hand, which is then remembered.
class AppCategoryDefaults {
  const AppCategoryDefaults._();

  static AppCategory forApplication(String id) =>
      _defaults[id.toLowerCase()] ?? AppCategory.other;

  static const Map<String, AppCategory> _defaults = <String, AppCategory>{
    // Work — writing, building, designing.
    'code.exe': AppCategory.work,
    'cursor.exe': AppCategory.work,
    'devenv.exe': AppCategory.work,
    'idea64.exe': AppCategory.work,
    'studio64.exe': AppCategory.work,
    'pycharm64.exe': AppCategory.work,
    'webstorm64.exe': AppCategory.work,
    'rider64.exe': AppCategory.work,
    'sublime_text.exe': AppCategory.work,
    'figma.exe': AppCategory.work,
    'photoshop.exe': AppCategory.work,
    'illustrator.exe': AppCategory.work,
    'blender.exe': AppCategory.work,
    'winword.exe': AppCategory.work,
    'excel.exe': AppCategory.work,
    'powerpnt.exe': AppCategory.work,
    'notion.exe': AppCategory.work,
    'obsidian.exe': AppCategory.work,
    'windowsterminal.exe': AppCategory.work,
    'powershell.exe': AppCategory.work,
    'cmd.exe': AppCategory.work,
    'com.microsoft.vscode': AppCategory.work,
    'com.todesktop.230313mzl4w4u92': AppCategory.work,
    'com.apple.dt.xcode': AppCategory.work,
    'com.jetbrains.intellij': AppCategory.work,
    'com.figma.desktop': AppCategory.work,
    'com.adobe.photoshop': AppCategory.work,
    'com.notion.desktop': AppCategory.work,
    'md.obsidian': AppCategory.work,
    'com.apple.terminal': AppCategory.work,
    'com.googlecode.iterm2': AppCategory.work,
    'com.microsoft.word': AppCategory.work,
    'com.microsoft.excel': AppCategory.work,
    'com.apple.iwork.pages': AppCategory.work,
    'com.apple.iwork.numbers': AppCategory.work,

    // Communication.
    'discord.exe': AppCategory.communication,
    'slack.exe': AppCategory.communication,
    'teams.exe': AppCategory.communication,
    'ms-teams.exe': AppCategory.communication,
    'zoom.exe': AppCategory.communication,
    'telegram.exe': AppCategory.communication,
    'whatsapp.exe': AppCategory.communication,
    'outlook.exe': AppCategory.communication,
    'thunderbird.exe': AppCategory.communication,
    'com.hnc.discord': AppCategory.communication,
    'com.tinyspeck.slackmacgap': AppCategory.communication,
    'com.microsoft.teams2': AppCategory.communication,
    'us.zoom.xos': AppCategory.communication,
    'ru.keepcoder.telegram': AppCategory.communication,
    'net.whatsapp.whatsapp': AppCategory.communication,
    'com.apple.mail': AppCategory.communication,
    'com.apple.messages': AppCategory.communication,

    // Browsing.
    'chrome.exe': AppCategory.browsing,
    'msedge.exe': AppCategory.browsing,
    'firefox.exe': AppCategory.browsing,
    'brave.exe': AppCategory.browsing,
    'opera.exe': AppCategory.browsing,
    'arc.exe': AppCategory.browsing,
    'com.google.chrome': AppCategory.browsing,
    'com.apple.safari': AppCategory.browsing,
    'org.mozilla.firefox': AppCategory.browsing,
    'com.brave.browser': AppCategory.browsing,
    'company.thebrowser.browser': AppCategory.browsing,
    'com.microsoft.edgemac': AppCategory.browsing,

    // Media.
    'spotify.exe': AppCategory.media,
    'vlc.exe': AppCategory.media,
    'mpc-hc64.exe': AppCategory.media,
    'netflix.exe': AppCategory.media,
    'com.spotify.client': AppCategory.media,
    'com.apple.music': AppCategory.media,
    'com.apple.tv': AppCategory.media,
    'org.videolan.vlc': AppCategory.media,
    'com.colliderli.iina': AppCategory.media,

    // Games.
    'steam.exe': AppCategory.games,
    'steamwebhelper.exe': AppCategory.games,
    'epicgameslauncher.exe': AppCategory.games,
    'battle.net.exe': AppCategory.games,
    'leagueclient.exe': AppCategory.games,
    'riotclientux.exe': AppCategory.games,
    'minecraft.exe': AppCategory.games,
    'com.valvesoftware.steam': AppCategory.games,

    // The desk itself.
    'explorer.exe': AppCategory.system,
    'systemsettings.exe': AppCategory.system,
    'taskmgr.exe': AppCategory.system,
    'applicationframehost.exe': AppCategory.system,
    'tempo.exe': AppCategory.system,
    'com.apple.finder': AppCategory.system,
    'com.apple.systempreferences': AppCategory.system,
    'com.apple.activitymonitor': AppCategory.system,
    'com.tempo.desktop': AppCategory.system,
  };
}
