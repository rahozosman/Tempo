import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/window_effects.dart';
import '../../core/constants/app_info.dart';
import '../../core/platform/tempo_platform.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/utilities/tempo_format.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../data/database/tempo_database.dart';
import '../../domain/analytics/insight_report.dart';
import '../../domain/tracking/tracking_status.dart';
import '../../platform/startup/startup_controller.dart';
import '../../platform/usage_tracking/usage_tracking_platform.dart';
import '../../platform/usage_tracking/usage_tracking_providers.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_dialog.dart';
import '../../shared/widgets/glass/glass_segmented.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/tempo_icon.dart';
import '../../shared/widgets/tempo_toast.dart';
import '../insights/insights_controller.dart';
import '../shell/shell_controller.dart';
import '../sharing/share_sheet.dart';
import 'appearance_controller.dart';
import 'data_maintenance_panel.dart';
import 'diagnostics_panel.dart';
import 'export_service.dart';
import 'preferences_controller.dart';

/// Settings. Everything here does something today; anything that needs the
/// tracking engine or the database arrives with them rather than sitting here
/// as a switch that does nothing.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _exporting = false;

  static String get _platformName {
    if (TempoPlatform.isMacOS) {
      return 'macOS';
    }
    if (TempoPlatform.isWindows) {
      return 'Windows';
    }
    return 'Desktop';
  }

  Future<void> _export(ExportFormat format) async {
    if (_exporting) {
      return;
    }
    setState(() => _exporting = true);
    try {
      final ExportResult result = await ExportService.export(
        repository: ref.read(analyticsRepositoryProvider),
        format: format,
        isPreview: ref.read(previewDataProvider),
        // JSON carries the sessions themselves, which is what makes it
        // restorable rather than just readable.
        usage: ref.read(databaseProvider)?.usage,
      );
      if (!mounted) {
        return;
      }
      final String message = result.isEmpty
          ? 'There is nothing recorded to export yet.'
          : result.path == null
          ? 'Tempo could not find a folder to save into.'
          : 'Exported ${TempoFormat.count(result.days, 'day')} as '
                '${format.label}  ·  ${result.path}';
      TempoToast.show(
        context,
        message,
        glyph: result.path == null ? TempoGlyph.info : TempoGlyph.sparkle,
        isError: result.path == null,
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  /// Deletes the stored history, after saying exactly what will go.
  Future<void> _deleteHistory() async {
    final TempoDatabase? database = ref.read(databaseProvider);
    if (database == null) {
      return;
    }
    final int days = await database.usage.recordedDays();
    if (!mounted) {
      return;
    }
    if (days == 0) {
      TempoToast.show(
        context,
        'There is nothing recorded to delete yet.',
        glyph: TempoGlyph.info,
      );
      return;
    }

    final bool? confirmed = await GlassDialog.show<bool>(
      context: context,
      builder: (BuildContext context) => GlassDialog(
        width: 480,
        title: 'Delete everything Tempo has recorded?',
        subtitle: 'This cannot be undone.',
        actions: <Widget>[
          GlassButton(
            label: 'Keep it',
            style: GlassButtonStyle.quiet,
            compact: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          GlassButton(
            label: 'Delete history',
            style: GlassButtonStyle.danger,
            compact: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
        child: Text(
          '${TempoFormat.count(days, 'day')} of usage history will be removed '
          'from this computer, along with every session behind it. Tempo keeps '
          'no copy anywhere else, so there is nothing to restore from.',
          style: context.typo.bodyLarge,
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final int removed = await database.usage.deleteAll();
    ref.read(usageRevisionProvider.notifier).bump();
    if (!mounted) {
      return;
    }
    TempoToast.show(
      context,
      'Deleted ${TempoFormat.count(removed, 'day')} of history.',
    );
  }

  void _openLicenses() {
    final ThemeData theme = Theme.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => Theme(
          data: theme.copyWith(
            scaffoldBackgroundColor: theme
                .extension<TempoTheme>()
                ?.colors
                .backdrop,
          ),
          child: LicensePage(
            applicationName: AppInfo.name,
            applicationVersion: 'Version ${AppInfo.version}',
            applicationLegalese: AppInfo.privacyLine,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppearanceState appearance = ref.watch(appearanceProvider);
    final AppearanceController appearanceController = ref.read(
      appearanceProvider.notifier,
    );
    final TempoPreferences preferences = ref.watch(preferencesProvider);
    final PreferencesController preferencesController = ref.read(
      preferencesProvider.notifier,
    );
    final bool railed = ref.watch(sidebarCollapsedProvider);
    final bool preview = ref.watch(previewDataProvider);
    final TempoDatabase? database = ref.watch(databaseProvider);
    final InsightSpan span = ref.watch(insightSpanProvider);
    final InsightReport? report = ref.watch(insightReportProvider).value;
    final TrackingStatus tracking = ref.watch(trackingStatusProvider);
    final UsageTrackingPlatform trackingPlatform = ref.watch(
      usageTrackingPlatformProvider,
    );
    // Anything but an unsupported system or a missing database can be paused
    // and resumed, including before the engine has started.
    final bool canToggleTracking = tracking != TrackingStatus.unavailable;
    final TrackingPermission? permission = ref
        .watch(trackingPermissionProvider)
        .value;
    final AsyncValue<bool> startup = ref.watch(startupProvider);

    return PageScaffold(
      title: 'Settings',
      subtitle: 'Tempo runs entirely on this computer.',
      child: ListView(
        padding: const EdgeInsets.only(bottom: TempoSpace.xl),
        children: <Widget>[
          const _SectionLabel('Appearance'),
          _SettingsCard(
            children: <Widget>[
              _SettingRow(
                title: 'Theme',
                description: 'Midnight, daylight, or follow the system.',
                trailing: SizedBox(
                  width: 260,
                  child: TempoSegmented<ThemeMode>(
                    value: appearance.themeMode,
                    onChanged: appearanceController.setThemeMode,
                    segments: const <TempoSegment<ThemeMode>>[
                      TempoSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: 'System',
                      ),
                      TempoSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: 'Daylight',
                      ),
                      TempoSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: 'Midnight',
                      ),
                    ],
                  ),
                ),
              ),
              _SettingRow(
                title: 'Element size',
                description:
                    'Makes text, icons, buttons and marks larger or smaller. '
                    'The layout stays where it is: pages get longer, not '
                    'narrower. Cmd/Ctrl + and - change it from anywhere; '
                    'Cmd/Ctrl 0 returns to 100%.',
                trailing: _ScaleControl(
                  value: appearance.elementScale,
                  onChanged: appearanceController.setElementScale,
                  onStepDown: appearanceController.smallerElements,
                  onStepUp: appearanceController.largerElements,
                ),
              ),
              _SettingRow(
                title: 'Glass',
                description:
                    'How frosted the surfaces are. Lower is clearer, with more '
                    'of the room showing through; higher is milkier and more '
                    'solid. Blur follows it.',
                trailing: _SliderControl(
                  value: appearance.glass,
                  min: AppearanceState.minGlass,
                  max: AppearanceState.maxGlass,
                  divisions: 12,
                  readout: '${(appearance.glass * 100).round()}%',
                  onChanged: appearanceController.setGlass,
                ),
              ),
              _SettingRow(
                title: 'Accent intensity',
                description: 'How strongly the blues and violets glow.',
                trailing: _SliderControl(
                  value: appearance.accentIntensity,
                  min: 0.4,
                  max: 1.4,
                  divisions: 10,
                  readout: '${(appearance.accentIntensity * 100).round()}%',
                  onChanged: appearanceController.setAccentIntensity,
                ),
              ),
              _SettingRow(
                title: 'Window blur',
                description: TempoWindowEffect.isSupported
                    ? 'Lets the desktop show through the window, using the '
                          'material the system provides. Turning it off keeps '
                          'the window solid.'
                    : 'This system cannot blur behind a window, so Tempo keeps '
                          'its own background instead.',
                trailing: SizedBox(
                  width: 200,
                  child: Opacity(
                    opacity: TempoWindowEffect.isSupported ? 1 : 0.4,
                    child: TempoSegmented<bool>(
                      value:
                          preferences.windowBlur &&
                          TempoWindowEffect.isSupported,
                      onChanged: TempoWindowEffect.isSupported
                          ? (bool value) => preferencesController
                                .setWindowBlur(enabled: value)
                          : (bool _) {},
                      segments: const <TempoSegment<bool>>[
                        TempoSegment<bool>(value: false, label: 'Off'),
                        TempoSegment<bool>(value: true, label: 'On'),
                      ],
                    ),
                  ),
                ),
              ),
              _SettingRow(
                title: 'Sidebar',
                description:
                    'Keep the labels, or fold the sidebar into its rail. '
                    'Narrow windows fold it automatically.',
                trailing: SizedBox(
                  width: 200,
                  child: TempoSegmented<bool>(
                    value: railed,
                    onChanged: ref.read(sidebarCollapsedProvider.notifier).set,
                    segments: const <TempoSegment<bool>>[
                      TempoSegment<bool>(value: false, label: 'Full'),
                      TempoSegment<bool>(value: true, label: 'Rail'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          const _SectionLabel('General'),
          _SettingsCard(
            children: <Widget>[
              _SettingRow(
                title: 'Keep running in the background',
                description:
                    'Closing the window leaves Tempo measuring from the tray, '
                    'where you can open it again, pause it or quit properly. '
                    'Turn this off and closing the window quits the app.',
                trailing: SizedBox(
                  width: 200,
                  child: TempoSegmented<bool>(
                    value: preferences.keepRunningInBackground,
                    onChanged: (bool value) => preferencesController
                        .setKeepRunningInBackground(enabled: value),
                    segments: const <TempoSegment<bool>>[
                      TempoSegment<bool>(value: true, label: 'Tray'),
                      TempoSegment<bool>(value: false, label: 'Quit'),
                    ],
                  ),
                ),
              ),
              _SettingRow(
                title: 'Launch at startup',
                description: startup.hasError
                    ? 'This system would not let Tempo change its startup '
                          'setting. It can be set from the system settings '
                          'instead.'
                    : 'Opens Tempo when you sign in, through the startup '
                          'mechanism the system already has. Turning it off '
                          'here removes it again.',
                trailing: SizedBox(
                  width: 200,
                  child: TempoSegmented<bool>(
                    value: startup.value ?? false,
                    onChanged: (bool value) => unawaited(
                      ref.read(startupProvider.notifier).set(enabled: value),
                    ),
                    segments: const <TempoSegment<bool>>[
                      TempoSegment<bool>(value: false, label: 'Off'),
                      TempoSegment<bool>(value: true, label: 'On'),
                    ],
                  ),
                ),
              ),
              _SettingRow(
                title: 'Weekly digest',
                description:
                    'One summary of the week just gone, sent once when the '
                    'week turns: the total, the daily average, what led, and '
                    'how it compares.',
                trailing: SizedBox(
                  width: 200,
                  child: TempoSegmented<bool>(
                    value: preferences.weeklyDigest,
                    onChanged: (bool value) =>
                        preferencesController.setWeeklyDigest(enabled: value),
                    segments: const <TempoSegment<bool>>[
                      TempoSegment<bool>(value: false, label: 'Off'),
                      TempoSegment<bool>(value: true, label: 'On'),
                    ],
                  ),
                ),
              ),
              _SettingRow(
                title: 'Notifications',
                description:
                    'When today passes your goal, when an application reaches '
                    'its daily limit, and when one has had two unbroken '
                    'hours. Never more than once each per day.',
                trailing: SizedBox(
                  width: 200,
                  child: TempoSegmented<bool>(
                    value: preferences.notificationsEnabled,
                    onChanged: (bool value) => preferencesController
                        .setNotificationsEnabled(enabled: value),
                    segments: const <TempoSegment<bool>>[
                      TempoSegment<bool>(value: false, label: 'Off'),
                      TempoSegment<bool>(value: true, label: 'On'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          const _SectionLabel('Tracking'),
          _SettingsCard(
            children: <Widget>[
              _SettingRow(
                title: tracking.title,
                description: trackingPlatform.capabilityNote,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(tracking.detail, style: context.typo.labelMedium),
                    const SizedBox(width: TempoSpace.sm),
                    GlassButton(
                      label: preferences.trackingEnabled ? 'Pause' : 'Resume',
                      glyph: preferences.trackingEnabled
                          ? TempoGlyph.pause
                          : TempoGlyph.play,
                      compact: true,
                      onPressed: canToggleTracking
                          ? () => preferencesController.setTrackingEnabled(
                              enabled: !preferences.trackingEnabled,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              _SettingRow(
                title: 'Permission',
                description:
                    'What this system asks for before Tempo can see which '
                    'application is in front.',
                trailing: Text(switch (permission) {
                  TrackingPermission.notRequired => 'None needed',
                  TrackingPermission.granted => 'Granted',
                  TrackingPermission.denied => 'Refused',
                  TrackingPermission.unsupported => 'Not supported',
                  null => 'Checking…',
                }, style: context.typo.labelMedium),
              ),
              _SettingRow(
                title: 'Idle timeout',
                description:
                    'How long the machine may sit untouched before Tempo stops '
                    'counting the time towards an application. Idle time is '
                    'still shown, it just belongs to no application.',
                trailing: SizedBox(
                  width: 320,
                  child: TempoSegmented<int>(
                    value: preferences.idleTimeout.inMinutes,
                    onChanged: (int minutes) => preferencesController
                        .setIdleTimeout(Duration(minutes: minutes)),
                    segments: const <TempoSegment<int>>[
                      TempoSegment<int>(value: 1, label: '1m'),
                      TempoSegment<int>(value: 5, label: '5m'),
                      TempoSegment<int>(value: 10, label: '10m'),
                      TempoSegment<int>(value: 15, label: '15m'),
                      TempoSegment<int>(value: 0, label: 'Never'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          const _SectionLabel('Screen time'),
          _SettingsCard(
            children: <Widget>[
              _SettingRow(
                title: 'Daily goal',
                description:
                    'Today shows how the day is going against this. Passing it '
                    'is noted, not scolded.',
                trailing: _SliderControl(
                  value: preferences.dailyGoal.inMinutes / 60,
                  min: 1,
                  max: 12,
                  divisions: 22,
                  readout: TempoFormat.hm(preferences.dailyGoal),
                  onChanged: (double hours) => preferencesController
                      .setDailyGoal(Duration(minutes: (hours * 60).round())),
                ),
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          const _SectionLabel('Sharing'),
          _SettingsCard(
            children: <Widget>[
              _SettingRow(
                title: 'Application names',
                description:
                    'Whether a shared report names the applications you used, '
                    'or gives the totals only.',
                trailing: SizedBox(
                  width: 200,
                  child: TempoSegmented<bool>(
                    value: preferences.includeApplicationNames,
                    onChanged: preferencesController.setIncludeApplicationNames,
                    segments: const <TempoSegment<bool>>[
                      TempoSegment<bool>(value: true, label: 'Include'),
                      TempoSegment<bool>(value: false, label: 'Hide'),
                    ],
                  ),
                ),
              ),
              _SettingRow(
                title: 'Share a report',
                description:
                    'Builds a card and a message from ${span.title}. Copy it, '
                    'save it, or hand it to WhatsApp — Tempo never sends '
                    'anything itself.',
                trailing: GlassButton(
                  label: 'Open share',
                  glyph: TempoGlyph.sparkle,
                  compact: true,
                  onPressed: report == null || report.isEmpty
                      ? null
                      : () => ShareSheet.open(
                          context,
                          report: report,
                          span: span,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          const _SectionLabel('Your data'),
          _SettingsCard(
            children: <Widget>[
              _SettingRow(
                title: 'Export history',
                description:
                    'Writes everything Tempo has stored to your Downloads '
                    'folder: a row per application per day, with the day '
                    'totals beside it.',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    GlassButton(
                      label: 'CSV',
                      compact: true,
                      onPressed: _exporting
                          ? null
                          : () => _export(ExportFormat.csv),
                    ),
                    const SizedBox(width: TempoSpace.xs),
                    GlassButton(
                      label: 'JSON',
                      compact: true,
                      onPressed: _exporting
                          ? null
                          : () => _export(ExportFormat.json),
                    ),
                  ],
                ),
              ),
              _SettingRow(
                title: 'Delete history',
                description: preview
                    ? 'Removes everything stored on this computer. Preview '
                          'data is generated rather than stored, so it is not '
                          'affected.'
                    : 'Removes every session and summary from this computer. '
                          'It cannot be undone, because nothing is kept '
                          'anywhere else.',
                trailing: GlassButton(
                  label: 'Delete…',
                  style: GlassButtonStyle.danger,
                  compact: true,
                  onPressed: database == null ? null : _deleteHistory,
                ),
              ),
              _SettingRow(
                title: 'Where it is stored',
                description:
                    'One SQLite file in the application-support folder for '
                    'this computer. Nothing is written anywhere else.',
                trailing: SizedBox(
                  width: 280,
                  child: Text(
                    database?.path ?? 'Database unavailable',
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typo.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.lg),
          const DataMaintenanceSection(),
          const SizedBox(height: TempoSpace.lg),
          const DiagnosticsSection(),
          const SizedBox(height: TempoSpace.lg),
          const _SectionLabel('Privacy'),
          GlassCard(
            hoverLift: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _LeadingGlyph(glyph: TempoGlyph.lock),
                const SizedBox(width: TempoSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Everything stays on this device',
                        style: context.typo.titleMedium,
                      ),
                      const SizedBox(height: TempoSpace.xxs),
                      Text(
                        'Tempo has no account, no analytics and no cloud. Your '
                        'usage history is stored locally and is never '
                        'uploaded. The only time anything leaves this computer '
                        'is when you share a report yourself, and you see '
                        'exactly what it says first.',
                        style: context.typo.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (kDebugMode) ...<Widget>[
            const SizedBox(height: TempoSpace.lg),
            const _SectionLabel('Developer'),
            _SettingsCard(
              children: <Widget>[
                _SettingRow(
                  title: 'Preview data',
                  description:
                      'Fills the screens with sample activity so the design '
                      'can be judged before the usage engine exists. The '
                      'window shows a badge while it is on, shared reports are '
                      'stamped, and a release build cannot turn it on at all.',
                  trailing: SizedBox(
                    width: 200,
                    child: TempoSegmented<bool>(
                      value: preview,
                      onChanged: ref.read(previewDataProvider.notifier).set,
                      segments: const <TempoSegment<bool>>[
                        TempoSegment<bool>(value: false, label: 'Off'),
                        TempoSegment<bool>(value: true, label: 'On'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: TempoSpace.lg),
          const _SectionLabel('About'),
          _SettingsCard(
            children: <Widget>[
              _SettingRow(
                title: AppInfo.name,
                description: AppInfo.tagline,
                trailing: Text(
                  'Version ${AppInfo.version}',
                  style: context.typo.labelMedium,
                ),
              ),
              _SettingRow(
                title: 'Platform',
                description:
                    'Tempo uses each system in its own way, so what it can '
                    'measure differs slightly between them.',
                trailing: Text(_platformName, style: context.typo.labelMedium),
              ),
              _SettingRow(
                title: 'New versions',
                description:
                    'Opens the releases page in your browser. Tempo never '
                    'checks by itself, and makes no network request of its '
                    'own — your browser makes that one.',
                trailing: GlassButton(
                  label: 'Releases',
                  glyph: TempoGlyph.sparkle,
                  compact: true,
                  onPressed: () => unawaited(
                    launchUrl(
                      Uri.parse(AppInfo.releasesUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
              ),
              _SettingRow(
                title: 'Open-source licenses',
                description:
                    'The libraries Tempo is built on, and their licenses.',
                trailing: GlassButton(
                  label: 'View',
                  glyph: TempoGlyph.info,
                  compact: true,
                  onPressed: _openLicenses,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A settings group: rows separated by hairlines, in one glass card.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      hoverLift: false,
      padding: const EdgeInsets.symmetric(
        horizontal: TempoSpace.lg,
        vertical: TempoSpace.xs,
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i != 0) const _RowDivider(),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: TempoSpace.xxs,
        bottom: TempoSpace.sm,
      ),
      child: Text(text.toUpperCase(), style: context.typo.labelSmall),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.description,
    required this.trailing,
  });

  final String title;
  final String description;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TempoSpace.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.typo.titleSmall),
                const SizedBox(height: TempoSpace.xxs - 1),
                Text(description, style: context.typo.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: TempoSpace.lg),
          trailing,
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: context.colors.border);
}

class _LeadingGlyph extends StatelessWidget {
  const _LeadingGlyph({required this.glyph});

  final TempoGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TempoRadius.sm),
        color: c.accent.withValues(alpha: 0.12),
        border: Border.all(color: c.accent.withValues(alpha: 0.22)),
      ),
      child: Center(child: TempoIcon(glyph, size: 19, color: c.accentSoft)),
    );
  }
}

/// A slider with a live readout and a dot that glows exactly as the rest of
/// the app will.
/// The element-size line.
///
/// Nothing is resized while the thumb is being dragged: the readout follows
/// the drag, and the size is applied once on release, so the control never
/// moves under the cursor. The end buttons move one step at a time.
class _ScaleControl extends StatefulWidget {
  const _ScaleControl({
    required this.value,
    required this.onChanged,
    required this.onStepDown,
    required this.onStepUp,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onStepDown;
  final VoidCallback onStepUp;

  @override
  State<_ScaleControl> createState() => _ScaleControlState();
}

class _ScaleControlState extends State<_ScaleControl> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final double shown = _dragging ?? widget.value;
    final int divisions =
        ((AppearanceState.maxScale - AppearanceState.minScale) /
                AppearanceState.scaleStep)
            .round();

    return SizedBox(
      width: 300,
      child: Row(
        children: <Widget>[
          GlassIconButton(
            glyph: TempoGlyph.minimize,
            tooltip: 'Smaller',
            size: 28,
            onPressed: widget.value > AppearanceState.minScale + 0.001
                ? widget.onStepDown
                : null,
          ),
          const SizedBox(width: TempoSpace.xs),
          Expanded(
            child: Slider(
              value: shown.clamp(
                AppearanceState.minScale,
                AppearanceState.maxScale,
              ),
              min: AppearanceState.minScale,
              max: AppearanceState.maxScale,
              divisions: divisions,
              onChangeStart: (double value) =>
                  setState(() => _dragging = value),
              onChanged: (double value) => setState(() => _dragging = value),
              onChangeEnd: (double value) {
                setState(() => _dragging = null);
                widget.onChanged(value);
              },
            ),
          ),
          const SizedBox(width: TempoSpace.xs),
          GlassIconButton(
            glyph: TempoGlyph.plus,
            tooltip: 'Larger',
            size: 28,
            onPressed: widget.value < AppearanceState.maxScale - 0.001
                ? widget.onStepUp
                : null,
          ),
          const SizedBox(width: TempoSpace.xs),
          SizedBox(
            width: 44,
            child: Text(
              '${(shown * 100).round()}%',
              textAlign: TextAlign.right,
              style: context.typo.labelMedium?.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderControl extends StatelessWidget {
  const _SliderControl({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.readout,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final String readout;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 264,
      child: Row(
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: context.tempo.accentGradient,
              boxShadow: context.tempo.accentGlow(1.4),
            ),
          ),
          const SizedBox(width: TempoSpace.sm),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: TempoSpace.xs),
          SizedBox(
            width: 52,
            child: Text(
              readout,
              textAlign: TextAlign.right,
              style: context.typo.labelMedium?.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
