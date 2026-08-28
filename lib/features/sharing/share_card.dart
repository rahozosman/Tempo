import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_info.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_palette.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/theme/tempo_typography.dart';
import '../../core/utilities/tempo_format.dart';
import '../../domain/analytics/app_usage.dart';
import '../../domain/analytics/insight_report.dart';
import '../../shared/widgets/tempo_mark.dart';
import '../insights/insights_controller.dart';

/// The image a report is shared as.
///
/// It is always drawn in the midnight identity, whatever appearance the app is
/// running in, so the picture that leaves the machine always looks the same.
/// The size is fixed so the exported file is predictable.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.report,
    required this.span,
    required this.includeApplicationNames,
    required this.isPreview,
  });

  static const double width = 460;
  static const double height = 640;

  final InsightReport report;
  final InsightSpan span;
  final bool includeApplicationNames;
  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: TempoThemeData.dark(),
      child: Builder(
        builder: (BuildContext context) {
          final TempoColors c = context.colors;
          final List<AppUsage> apps = report.apps.length > 3
              ? report.apps.sublist(0, 3)
              : report.apps;
          final double? change = report.change;

          return SizedBox(
            width: width,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[c.surface, c.backdropEdge],
                ),
              ),
              child: CustomPaint(
                painter: _CardGlow(colors: c),
                child: Padding(
                  padding: const EdgeInsets.all(TempoSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const TempoMark(size: 26, glow: false),
                          const SizedBox(width: TempoSpace.xs + 2),
                          Text(
                            AppInfo.name.toUpperCase(),
                            style: context.typo.labelSmall?.copyWith(
                              color: c.textSecondary,
                              letterSpacing: 3,
                            ),
                          ),
                          const Spacer(),
                          if (isPreview)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: c.warning.withValues(alpha: 0.16),
                                border: Border.all(
                                  color: c.warning.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                'PREVIEW DATA',
                                style: context.typo.labelSmall?.copyWith(
                                  color: c.warning,
                                  fontSize: 9,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        span.shareHeading,
                        style: context.typo.labelSmall?.copyWith(
                          color: c.accentSoft,
                          letterSpacing: 4,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: TempoSpace.sm),
                      Text(
                        TempoFormat.hm(report.screenTime),
                        style: TempoTypography.hero.copyWith(
                          color: c.textPrimary,
                          fontFeatures: TempoTypography.numeric,
                        ),
                      ),
                      const SizedBox(height: TempoSpace.xxs),
                      Text(
                        'Screen time · ${span.describe(report.start, report.end)}',
                        style: context.typo.bodyMedium,
                      ),
                      const SizedBox(height: TempoSpace.lg),
                      Row(
                        children: <Widget>[
                          _Pill(
                            label: 'Daily average',
                            value: TempoFormat.hm(report.dailyAverage),
                          ),
                          const SizedBox(width: TempoSpace.xs),
                          if (change != null)
                            _Pill(
                              label: 'vs ${span.previousLabel}',
                              value: TempoFormat.signedPercent(change),
                              tone: c.accentSoft,
                            ),
                        ],
                      ),
                      const Spacer(),
                      if (includeApplicationNames && apps.isNotEmpty) ...<Widget>[
                        Text(
                          'TOP APPLICATIONS',
                          style: context.typo.labelSmall,
                        ),
                        const SizedBox(height: TempoSpace.sm),
                        for (final AppUsage app in apps)
                          _AppLine(
                            app: app,
                            total: report.activeTime,
                            tone: TempoPalette.toneFor(c, app.id),
                          ),
                      ] else
                        Text(
                          'Application names left out of this report.',
                          style: context.typo.bodySmall,
                        ),
                      const Spacer(),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              AppInfo.privacyLine,
                              style: context.typo.bodySmall?.copyWith(
                                fontSize: 11,
                                color: c.textTertiary,
                              ),
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: context.tempo.accentWideGradient,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TempoSpace.sm,
        vertical: TempoSpace.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TempoRadius.sm),
        color: c.glassFill,
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: context.typo.titleSmall?.copyWith(
              color: tone ?? c.textPrimary,
              fontFeatures: TempoTypography.numeric,
            ),
          ),
          const SizedBox(width: TempoSpace.xs),
          Text(
            label,
            style: context.typo.bodySmall?.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _AppLine extends StatelessWidget {
  const _AppLine({
    required this.app,
    required this.total,
    required this.tone,
  });

  final AppUsage app;
  final Duration total;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final double share = app.shareOf(total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: TempoSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: tone),
              ),
              const SizedBox(width: TempoSpace.xs),
              Expanded(
                child: Text(
                  app.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.titleSmall,
                ),
              ),
              Text(
                TempoFormat.hm(app.duration),
                style: context.typo.labelLarge?.copyWith(
                  color: context.colors.textSecondary,
                  fontFeatures: TempoTypography.numeric,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(
                    color: context.colors.glassFill.withValues(alpha: 0.10),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: share,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: TempoPalette.gradientFor(tone),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two soft lights behind the card, in the product accents.
class _CardGlow extends CustomPainter {
  const _CardGlow({required this.colors});

  final TempoColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    void blob(Offset centre, double radius, Color color) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              color.withValues(alpha: 0.30),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    final double unit = math.min(size.width, size.height);
    blob(Offset(size.width * 0.82, size.height * 0.12), unit * 0.62, colors.accent);
    blob(
      Offset(size.width * 0.08, size.height * 0.74),
      unit * 0.70,
      colors.accentAlt,
    );
  }

  @override
  bool shouldRepaint(covariant _CardGlow oldDelegate) =>
      oldDelegate.colors.accent != colors.accent;
}
