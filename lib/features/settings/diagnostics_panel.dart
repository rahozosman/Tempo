import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../core/diagnostics/tempo_log.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/utilities/tempo_format.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_dialog.dart';
import '../../shared/widgets/tempo_icon.dart';
import '../../shared/widgets/tempo_toast.dart';
import 'diagnostics_controller.dart';

/// The Diagnostics section of Settings.
///
/// It exists because the parts of Tempo most likely to break are the parts
/// that break silently. This is where the app is asked, out loud, whether what
/// it has stored makes sense.
class DiagnosticsSection extends ConsumerWidget {
  const DiagnosticsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TempoColors c = context.colors;
    final AsyncValue<DiagnosticsReport> async = ref.watch(diagnosticsProvider);
    final DiagnosticsReport? report = async.value;

    final (String headline, Color tone) = switch (report) {
      null => ('Checking…', c.textSecondary),
      final DiagnosticsReport r when r.databasePath == null => (
        'Storage unavailable',
        c.danger,
      ),
      final DiagnosticsReport r when r.issues.isEmpty => (
        'Everything checks out',
        c.positive,
      ),
      final DiagnosticsReport r => (
        '${r.issues.length} thing${r.issues.length == 1 ? '' : 's'} to look at',
        c.warning,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            left: TempoSpace.xxs,
            bottom: TempoSpace.sm,
          ),
          child: Text('DIAGNOSTICS', style: context.typo.labelSmall),
        ),
        GlassCard(
          hoverLift: false,
          padding: const EdgeInsets.all(TempoSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tone,
                      boxShadow: context.tempo.glowOf(tone, 0.8),
                    ),
                  ),
                  const SizedBox(width: TempoSpace.sm),
                  Expanded(
                    child: Text(headline, style: context.typo.titleMedium),
                  ),
                  GlassButton(
                    label: 'Run checks',
                    glyph: TempoGlyph.insights,
                    compact: true,
                    onPressed: () {
                      ref.invalidate(diagnosticsProvider);
                      unawaitedOpen(context, ref);
                    },
                  ),
                ],
              ),
              const SizedBox(height: TempoSpace.sm),
              Text(
                'Tempo checks its own record: that no session crosses midnight '
                'or overlaps another, that every day’s totals match the '
                'sessions behind them, and that the file itself is sound.',
                style: context.typo.bodySmall,
              ),
              if (report != null) ...<Widget>[
                const SizedBox(height: TempoSpace.md),
                Container(height: 1, color: c.border),
                const SizedBox(height: TempoSpace.md),
                _Facts(report: report),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Opens the full report once it has been gathered.
  void unawaitedOpen(BuildContext context, WidgetRef ref) {
    Future<void>(() async {
      final DiagnosticsReport report = await ref.read(
        diagnosticsProvider.future,
      );
      if (!context.mounted) {
        return;
      }
      await GlassDialog.show<void>(
        context: context,
        builder: (BuildContext context) =>
            _DiagnosticsDialog(report: report),
      );
    });
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.report});

  final DiagnosticsReport report;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TempoSpace.xl,
      runSpacing: TempoSpace.sm,
      children: <Widget>[
        _Fact(label: 'Sessions', value: '${report.sessions}'),
        _Fact(label: 'Days', value: '${report.days}'),
        _Fact(label: 'Applications', value: '${report.applications}'),
        _Fact(label: 'Database', value: report.databaseSize),
        _Fact(
          label: 'Since',
          value: report.earliestDay == null
              ? '—'
              : TempoFormat.dayShort(report.earliestDay!),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label.toUpperCase(), style: context.typo.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: context.typo.titleSmall),
      ],
    );
  }
}

class _DiagnosticsDialog extends StatelessWidget {
  const _DiagnosticsDialog({required this.report});

  final DiagnosticsReport report;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return GlassDialog(
      width: 640,
      title: report.isHealthy
          ? 'Everything checks out'
          : 'What Tempo found',
      subtitle:
          'Gathered from the stored history and from the app itself. Nothing '
          'here leaves the computer unless you copy it somewhere.',
      actions: <Widget>[
        GlassButton(
          label: 'Open log folder',
          glyph: TempoGlyph.info,
          style: GlassButtonStyle.quiet,
          compact: true,
          onPressed: report.logPath == null
              ? null
              : () => unawaited(_openLogFolder(context, report.logPath!)),
        ),
        GlassButton(
          label: 'Copy report',
          glyph: TempoGlyph.today,
          compact: true,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: report.toText()));
            if (context.mounted) {
              TempoToast.show(context, 'Diagnostics copied to the clipboard.');
            }
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (report.issues.isEmpty)
            Text(
              'Every session belongs to one day, no two overlap, and every '
              'day’s totals match the sessions behind them.',
              style: context.typo.bodyLarge,
            )
          else
            for (final String issue in report.issues)
              Padding(
                padding: const EdgeInsets.only(bottom: TempoSpace.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TempoIcon(TempoGlyph.info, size: 16, color: c.warning),
                    const SizedBox(width: TempoSpace.sm),
                    Expanded(
                      child: Text(issue, style: context.typo.bodyLarge),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: TempoSpace.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(TempoSpace.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TempoRadius.md),
              color: c.glassFill,
              border: Border.all(color: c.border),
            ),
            child: SelectableText(
              report.toText(),
              style: context.typo.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLogFolder(BuildContext context, String logPath) async {
    final bool opened = await launchUrl(
      Uri.file(p.dirname(logPath)),
      mode: LaunchMode.externalApplication,
    ).catchError((Object error) {
      TempoLog.error('could not open the log folder', error);
      return false;
    });
    if (context.mounted && !opened) {
      TempoToast.show(
        context,
        'Tempo could not open the folder. It is at $logPath',
        glyph: TempoGlyph.info,
        isError: true,
      );
    }
  }
}