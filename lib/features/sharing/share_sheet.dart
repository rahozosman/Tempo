import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../domain/analytics/insight_report.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_dialog.dart';
import '../../shared/widgets/glass/glass_segmented.dart';
import '../../shared/widgets/tempo_icon.dart';
import '../../shared/widgets/tempo_toast.dart';
import '../insights/insights_controller.dart';
import '../settings/preferences_controller.dart';
import 'share_card.dart';
import 'share_report.dart';
import 'share_service.dart';

/// The share flow: the card as it will look, the text as it will read, and
/// four things the person can choose to do with it.
class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({super.key, required this.report, required this.span});

  final InsightReport report;
  final InsightSpan span;

  /// Opens the flow over the current screen.
  static Future<void> open(
    BuildContext context, {
    required InsightReport report,
    required InsightSpan span,
  }) => GlassDialog.show<void>(
    context: context,
    builder: (BuildContext context) =>
        ShareSheet(report: report, span: span),
  );

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _busy = false;

  String get _stamp =>
      DateFormat('yyyy-MM-dd').format(widget.report.end);

  String get _baseName =>
      'tempo-${widget.span.label.toLowerCase()}-$_stamp';

  Future<void> _run(Future<String?> Function() action, String success) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final String? result = await action();
      if (!mounted) {
        return;
      }
      if (result == null) {
        TempoToast.show(
          context,
          'Tempo could not find a folder to save into.',
          glyph: TempoGlyph.info,
          isError: true,
        );
      } else {
        TempoToast.show(context, '$success  ·  $result');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPreview = ref.watch(previewDataProvider);
    final bool includeNames = ref.watch(
      preferencesProvider.select(
        (TempoPreferences value) => value.includeApplicationNames,
      ),
    );
    final String text = buildShareText(
      report: widget.report,
      span: widget.span,
      includeApplicationNames: includeNames,
      isPreview: isPreview,
    );

    return GlassDialog(
      width: 620,
      title: 'Share your ${widget.span.label.toLowerCase()}',
      subtitle:
          'Nothing leaves this computer until you choose to send it. '
          'Saved files go to your Downloads folder.',
      actions: <Widget>[
        GlassButton(
          label: 'Copy text',
          glyph: TempoGlyph.today,
          style: GlassButtonStyle.quiet,
          compact: true,
          onPressed: _busy
              ? null
              : () async {
                  await ShareService.copy(text);
                  if (context.mounted) {
                    TempoToast.show(context, 'Report copied to the clipboard.');
                  }
                },
        ),
        GlassButton(
          label: 'Save text',
          glyph: TempoGlyph.info,
          compact: true,
          onPressed: _busy
              ? null
              : () => _run(
                  () => ShareService.saveText(text, '$_baseName.txt'),
                  'Report saved',
                ),
        ),
        GlassButton(
          label: 'Save image',
          glyph: TempoGlyph.apps,
          compact: true,
          onPressed: _busy
              ? null
              : () => _run(
                  () => ShareService.saveImage(_cardKey, '$_baseName.png'),
                  'Image saved',
                ),
        ),
        GlassButton(
          label: 'Share to WhatsApp',
          glyph: TempoGlyph.sparkle,
          style: GlassButtonStyle.primary,
          compact: true,
          onPressed: _busy
              ? null
              : () async {
                  final bool opened = await ShareService.openWhatsApp(text);
                  if (!context.mounted) {
                    return;
                  }
                  TempoToast.show(
                    context,
                    opened
                        ? 'WhatsApp opened with your report. Pick a chat and '
                              'send it yourself.'
                        : 'Tempo could not open WhatsApp. Copy the text '
                              'instead.',
                    glyph: opened ? TempoGlyph.sparkle : TempoGlyph.info,
                    isError: !opened,
                  );
                },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: SizedBox(
              width: ShareCard.width * 0.66,
              height: ShareCard.height * 0.66,
              child: FittedBox(
                child: RepaintBoundary(
                  key: _cardKey,
                  child: ShareCard(
                    report: widget.report,
                    span: widget.span,
                    includeApplicationNames: includeNames,
                    isPreview: isPreview,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: TempoSpace.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Application names',
                      style: context.typo.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Leave them out to share only the totals.',
                      style: context.typo.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TempoSpace.md),
              SizedBox(
                width: 190,
                child: TempoSegmented<bool>(
                  value: includeNames,
                  onChanged: ref
                      .read(preferencesProvider.notifier)
                      .setIncludeApplicationNames,
                  segments: const <TempoSegment<bool>>[
                    TempoSegment<bool>(value: true, label: 'Include'),
                    TempoSegment<bool>(value: false, label: 'Hide'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TempoSpace.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(TempoSpace.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TempoRadius.md),
              color: context.colors.glassFill,
              border: Border.all(color: context.colors.border),
            ),
            child: SelectableText(
              text,
              style: context.typo.bodyMedium?.copyWith(height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}
