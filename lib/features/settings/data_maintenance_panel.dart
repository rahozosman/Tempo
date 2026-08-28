import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/diagnostics/tempo_log.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/utilities/tempo_format.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../data/database/tempo_database.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_segmented.dart';
import '../../shared/widgets/tempo_icon.dart';
import '../../shared/widgets/tempo_toast.dart';
import 'import_service.dart';
import 'preferences_controller.dart';

/// Looking after the one copy of the data: how long to keep it, a backup that
/// can actually be restored, and a way to tidy the file itself.
class DataMaintenanceSection extends ConsumerStatefulWidget {
  const DataMaintenanceSection({super.key});

  @override
  ConsumerState<DataMaintenanceSection> createState() =>
      _DataMaintenanceSectionState();
}

class _DataMaintenanceSectionState
    extends ConsumerState<DataMaintenanceSection> {
  static final DateFormat _stamp = DateFormat('yyyy-MM-dd');

  bool _busy = false;

  Future<void> _run(Future<void> Function(TempoDatabase database) job) async {
    final TempoDatabase? database = ref.read(databaseProvider);
    if (_busy || database == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await job(database);
    } on Object catch (error, stack) {
      TempoLog.error('maintenance failed', error, stack);
      if (mounted) {
        TempoToast.show(
          context,
          'That did not work: $error',
          glyph: TempoGlyph.info,
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _backup(TempoDatabase database) async {
    final String? folder = _downloads();
    if (folder == null) {
      if (mounted) {
        TempoToast.show(
          context,
          'Tempo could not find a folder to save into.',
          glyph: TempoGlyph.info,
          isError: true,
        );
      }
      return;
    }
    final String path =
        '$folder${Platform.pathSeparator}'
        'tempo-backup-${_stamp.format(DateTime.now())}.db';
    await database.usage.backupTo(path);
    if (mounted) {
      TempoToast.show(context, 'Backed up  ·  $path');
    }
  }

  Future<void> _import(TempoDatabase database) async {
    final ImportResult result = await ImportService.importBackup(
      database.usage,
    );
    if (!mounted || result.cancelled) {
      return;
    }
    if (result.error != null) {
      TempoToast.show(
        context,
        result.error!,
        glyph: TempoGlyph.info,
        isError: true,
      );
      return;
    }
    ref.read(usageRevisionProvider.notifier).bump();
    TempoToast.show(
      context,
      result.sessions == 0
          ? 'Nothing new in that file — everything in it was already stored.'
          : 'Restored ${TempoFormat.count(result.sessions, 'session')} '
                'across ${TempoFormat.count(result.days, 'day')}.',
    );
  }

  Future<void> _optimise(TempoDatabase database) async {
    await database.usage.optimise();
    if (mounted) {
      TempoToast.show(context, 'Database tidied up.');
    }
  }

  static String? _downloads() {
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

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final TempoPreferences preferences = ref.watch(preferencesProvider);
    final bool available = ref.watch(databaseProvider) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            left: TempoSpace.xxs,
            bottom: TempoSpace.sm,
          ),
          child: Text('LOOKING AFTER IT', style: context.typo.labelSmall),
        ),
        GlassCard(
          hoverLift: false,
          padding: const EdgeInsets.symmetric(
            horizontal: TempoSpace.lg,
            vertical: TempoSpace.xs,
          ),
          child: Column(
            children: <Widget>[
              _Row(
                title: 'Keep history for',
                description:
                    'Older days are removed the next time Tempo starts. '
                    'Forever is the default: your own past is yours to keep.',
                trailing: SizedBox(
                  width: 320,
                  child: TempoSegmented<int>(
                    value: preferences.retentionDays,
                    onChanged: ref
                        .read(preferencesProvider.notifier)
                        .setRetentionDays,
                    segments: const <TempoSegment<int>>[
                      TempoSegment<int>(value: 0, label: 'Forever'),
                      TempoSegment<int>(value: 365, label: '1 year'),
                      TempoSegment<int>(value: 180, label: '6 months'),
                      TempoSegment<int>(value: 90, label: '3 months'),
                    ],
                  ),
                ),
              ),
              Container(height: 1, color: c.border),
              _Row(
                title: 'Back up',
                description:
                    'Writes a complete copy of the database to your Downloads '
                    'folder, taken safely while Tempo is running.',
                trailing: GlassButton(
                  label: 'Back up now',
                  glyph: TempoGlyph.year,
                  compact: true,
                  onPressed: available && !_busy
                      ? () => _run(_backup)
                      : null,
                ),
              ),
              Container(height: 1, color: c.border),
              _Row(
                title: 'Restore from an export',
                description:
                    'Reads a Tempo JSON export back in, session by session. '
                    'Importing the same file twice changes nothing.',
                trailing: GlassButton(
                  label: 'Choose a file',
                  glyph: TempoGlyph.apps,
                  compact: true,
                  onPressed: available && !_busy
                      ? () => _run(_import)
                      : null,
                ),
              ),
              Container(height: 1, color: c.border),
              _Row(
                title: 'Tidy the database',
                description:
                    'Rewrites the file compactly, reclaiming the space left by '
                    'anything deleted. Worth doing once in a while.',
                trailing: GlassButton(
                  label: 'Optimise',
                  glyph: TempoGlyph.sparkle,
                  compact: true,
                  onPressed: available && !_busy
                      ? () => _run(_optimise)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
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
