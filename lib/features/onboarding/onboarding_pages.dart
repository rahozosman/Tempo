import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../core/motion/tempo_animations.dart';
import '../../core/motion/tempo_motion.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../data/database/tempo_database.dart';
import '../../platform/startup/startup_controller.dart';
import '../../platform/usage_tracking/usage_tracking_platform.dart';
import '../../platform/usage_tracking/usage_tracking_providers.dart';
import '../../shared/widgets/glass/glass_segmented.dart';
import '../../shared/widgets/tempo_icon.dart';
import '../settings/preferences_controller.dart';

/// The four first-run pages.
///
/// Each one is a plain widget: the overlay owns the paging, the buttons and
/// the keyboard, so a page only has to say its piece. Every entrance is
/// staggered from the top down, and every animation routes its duration
/// through [TempoMotion] so "reduce motion" turns the whole flow static
/// rather than fast.

// ---------------------------------------------------------------------------
// 1 · Welcome
// ---------------------------------------------------------------------------

class OnboardingWelcome extends StatelessWidget {
  const OnboardingWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const _IconHero(),
        const SizedBox(height: TempoSpace.lg),
        TempoEntrance(
          index: 1,
          child: Text(AppInfo.name, style: context.typo.displaySmall),
        ),
        const SizedBox(height: TempoSpace.xxs),
        TempoEntrance(
          index: 2,
          child: ShaderMask(
            shaderCallback: (Rect bounds) =>
                context.tempo.accentWideGradient.createShader(bounds),
            child: Text(
              'Understand your time',
              style: context.typo.labelSmall?.copyWith(
                color: const Color(0xFFFFFFFF),
                fontSize: 11.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(
          index: 3,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Text(
              'Tempo keeps a quiet record of where your hours actually go — '
              'which application is in front of you, and for how long. '
              'No account, no cloud, nothing to sign in to.',
              textAlign: TextAlign.center,
              style: context.typo.bodyLarge?.copyWith(color: c.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: TempoSpace.lg),
        TempoEntrance(
          index: 4,
          child: Wrap(
            spacing: TempoSpace.xs,
            runSpacing: TempoSpace.xs,
            alignment: WrapAlignment.center,
            children: const <Widget>[
              _Chip(glyph: TempoGlyph.lock, label: 'Private by design'),
              _Chip(glyph: TempoGlyph.clock, label: 'Measures in the tray'),
              _Chip(glyph: TempoGlyph.sparkle, label: 'Yours to delete'),
            ],
          ),
        ),
      ],
    );
  }
}

/// The app icon, lifted off the page by its own glow, with a single point
/// travelling the orbit around it — the same idea as the Tempo mark.
class _IconHero extends StatefulWidget {
  const _IconHero();

  @override
  State<_IconHero> createState() => _IconHeroState();
}

class _IconHeroState extends State<_IconHero> with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  );
  late final CurvedAnimation _eased = CurvedAnimation(
    parent: _entrance,
    curve: TempoCurve.entrance,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (TempoMotion.reduced(context)) {
      _entrance.value = 1;
      return;
    }
    _entrance.forward();
    _orbit.repeat();
  }

  @override
  void dispose() {
    _eased.dispose();
    _entrance.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    const double box = 172;
    return SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_eased, _orbit]),
        builder: (BuildContext context, Widget? child) {
          final double t = _eased.value;
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CustomPaint(
                  size: const Size.square(box),
                  painter: _OrbitPainter(
                    colors: c,
                    reveal: t,
                    angle: _orbit.value * math.pi * 2,
                  ),
                ),
                Transform.scale(scale: 0.88 + 0.12 * t, child: child),
              ],
            ),
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: context.tempo.accentGlow(1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Image.asset(
              'assets/branding/tempo_icon.png',
              width: 116,
              height: 116,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({
    required this.colors,
    required this.reveal,
    required this.angle,
  });

  final TempoColors colors;
  final double reveal;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - 4;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.border.withValues(alpha: 0.9 * reveal),
    );

    final Offset dot =
        centre + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(
      dot,
      7,
      Paint()..color = colors.accentSoft.withValues(alpha: 0.18 * reveal),
    );
    canvas.drawCircle(
      dot,
      3,
      Paint()..color = colors.accentSoft.withValues(alpha: reveal),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.reveal != reveal ||
      oldDelegate.angle != angle ||
      oldDelegate.colors.accentSoft != colors.accentSoft;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.glyph, required this.label});

  final TempoGlyph glyph;
  final String label;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TempoSpace.sm,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: c.glassFill,
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TempoIcon(glyph, size: 13, color: c.accentSoft),
          const SizedBox(width: 6),
          Text(label, style: context.typo.labelMedium),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2 · What is measured
// ---------------------------------------------------------------------------

class OnboardingMeasures extends ConsumerWidget {
  const OnboardingMeasures({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TempoColors c = context.colors;
    final UsageTrackingPlatform platform = ref.watch(
      usageTrackingPlatformProvider,
    );
    final TrackingPermission? permission = ref
        .watch(trackingPermissionProvider)
        .value;
    final TempoDatabase? database = ref.watch(databaseProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _PageHeading(
          title: 'What Tempo measures',
          subtitle: 'All of it, before anything is recorded.',
        ),
        const SizedBox(height: TempoSpace.lg),
        const _Point(
          index: 1,
          glyph: TempoGlyph.clock,
          title: 'Which application is in front, and for how long',
          detail:
              'That is the whole measurement. Time you spend away from the '
              'keyboard is counted separately and belongs to no application.',
        ),
        const _Point(
          index: 2,
          glyph: TempoGlyph.lock,
          title: 'Nothing else is read, and nothing is sent',
          detail:
              'No window titles, no documents, no addresses, no screenshots. '
              'Tempo has no account and makes no network requests of its own.',
        ),
        _Point(
          index: 3,
          glyph: TempoGlyph.year,
          title: 'It all stays in one file on this computer',
          detail: database == null
              ? 'Tempo could not open its database, so nothing can be '
                    'recorded yet. Restarting the app usually clears this.'
              : 'You can export it or delete it whenever you like, from '
                    'Settings.',
        ),
        TempoEntrance(
          index: 4,
          child: Container(
            padding: const EdgeInsets.all(TempoSpace.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TempoRadius.md),
              color: c.glassFill,
              border: Border.all(color: c.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TempoIcon(TempoGlyph.info, size: 16, color: c.textTertiary),
                const SizedBox(width: TempoSpace.sm),
                Expanded(
                  child: Text(
                    '${platform.capabilityNote} '
                    '${permissionLine(permission)}',
                    style: context.typo.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// What this system asks of Tempo before it can measure.
String permissionLine(TrackingPermission? permission) => switch (permission) {
  TrackingPermission.notRequired =>
    'No permission is needed, and none is asked for.',
  TrackingPermission.granted => 'Permission is already granted.',
  TrackingPermission.denied =>
    'Permission has been refused, so application usage cannot be measured '
        'until it is granted in System Settings.',
  TrackingPermission.unsupported =>
    'This system is not supported, so nothing will be recorded.',
  null => '',
};

class _Point extends StatelessWidget {
  const _Point({
    required this.index,
    required this.glyph,
    required this.title,
    required this.detail,
  });

  final int index;
  final TempoGlyph glyph;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return TempoEntrance(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: TempoSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TempoRadius.sm),
                color: c.accent.withValues(alpha: 0.12),
                border: Border.all(color: c.accent.withValues(alpha: 0.22)),
              ),
              child: Center(
                child: TempoIcon(glyph, size: 17, color: c.accentSoft),
              ),
            ),
            const SizedBox(width: TempoSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title, style: context.typo.titleSmall),
                  const SizedBox(height: 2),
                  Text(detail, style: context.typo.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3 · What you will see
// ---------------------------------------------------------------------------

class OnboardingFeatures extends StatefulWidget {
  const OnboardingFeatures({super.key});

  @override
  State<OnboardingFeatures> createState() => _OnboardingFeaturesState();
}

class _OnboardingFeaturesState extends State<OnboardingFeatures>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _started = false;

  static const List<_Feature> _features = <_Feature>[
    _Feature(
      glyph: TempoGlyph.today,
      title: 'Today',
      caption: 'Your day against its goal, hour by hour.',
      kind: _VizKind.ring,
    ),
    _Feature(
      glyph: TempoGlyph.apps,
      title: 'Applications',
      caption: 'Everything you used, ranked by the time it took.',
      kind: _VizKind.rows,
    ),
    _Feature(
      glyph: TempoGlyph.week,
      title: 'Week',
      caption: 'Seven days side by side, with the shape of each one.',
      kind: _VizKind.bars,
    ),
    _Feature(
      glyph: TempoGlyph.month,
      title: 'Month',
      caption: 'A calendar that warms up on the days you worked.',
      kind: _VizKind.heat,
    ),
    _Feature(
      glyph: TempoGlyph.year,
      title: 'Year',
      caption: 'Every day of the year in one quiet grid.',
      kind: _VizKind.grid,
    ),
    _Feature(
      glyph: TempoGlyph.insights,
      title: 'Insights',
      caption: 'Plain sentences about what actually changed.',
      kind: _VizKind.spark,
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (TempoMotion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _PageHeading(
          title: 'Six ways to read the same day',
          subtitle:
              'The measurement never changes — only how far back you stand '
              'from it.',
        ),
        const SizedBox(height: TempoSpace.lg),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double gap = TempoSpace.sm;
            final double tile = (constraints.maxWidth - gap * 2) / 3;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (int i = 0; i < _features.length; i++)
                  SizedBox(
                    width: tile,
                    child: _FeatureTile(
                      feature: _features[i],
                      progress: _controller,
                      // Each tile draws itself a beat after the one before,
                      // so the grid fills like a page settling.
                      delay: 0.06 * i,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

enum _VizKind { ring, rows, bars, heat, grid, spark }

@immutable
class _Feature {
  const _Feature({
    required this.glyph,
    required this.title,
    required this.caption,
    required this.kind,
  });

  final TempoGlyph glyph;
  final String title;
  final String caption;
  final _VizKind kind;
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.feature,
    required this.progress,
    required this.delay,
  });

  final _Feature feature;
  final Animation<double> progress;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Container(
      padding: const EdgeInsets.all(TempoSpace.sm + 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TempoRadius.md),
        color: c.glassFill,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 34,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: progress,
                builder: (BuildContext context, Widget? child) {
                  final double t = Curves.easeOutCubic.transform(
                    ((progress.value - delay) / (1 - delay)).clamp(0.0, 1.0),
                  );
                  return CustomPaint(
                    painter: _VizPainter(kind: feature.kind, t: t, colors: c),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: TempoSpace.sm),
          Row(
            children: <Widget>[
              TempoIcon(feature.glyph, size: 14, color: c.accentSoft),
              const SizedBox(width: 6),
              Text(feature.title, style: context.typo.titleSmall),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            feature.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.typo.bodySmall?.copyWith(
              fontSize: 11.5,
              color: c.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The six miniature charts. Each one is the real chart's silhouette, drawn
/// small enough to read as a promise rather than as data.
class _VizPainter extends CustomPainter {
  const _VizPainter({
    required this.kind,
    required this.t,
    required this.colors,
  });

  final _VizKind kind;
  final double t;
  final TempoColors colors;

  static const List<double> _weights = <double>[
    0.42,
    0.66,
    0.30,
    0.88,
    0.54,
    0.74,
    0.36,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final Shader accent = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: <Color>[colors.accent, colors.accentSoft],
    ).createShader(Offset.zero & size);

    switch (kind) {
      case _VizKind.ring:
        final Offset centre = Offset(size.height / 2, size.height / 2);
        final double radius = size.height / 2 - 3;
        final Rect rect = Rect.fromCircle(center: centre, radius: radius);
        canvas.drawArc(
          rect,
          0,
          math.pi * 2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = colors.border,
        );
        canvas.drawArc(
          rect,
          -math.pi / 2,
          math.pi * 2 * 0.72 * t,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..shader = accent,
        );
      case _VizKind.rows:
        for (int i = 0; i < 3; i++) {
          final double y = 5.0 + i * 12;
          final double full = size.width * (0.92 - i * 0.24);
          canvas.drawRRect(
            RRect.fromLTRBR(
              0,
              y,
              size.width * 0.92,
              y + 5,
              const Radius.circular(3),
            ),
            Paint()..color = colors.border,
          );
          canvas.drawRRect(
            RRect.fromLTRBR(0, y, full * t, y + 5, const Radius.circular(3)),
            Paint()..shader = accent,
          );
        }
      case _VizKind.bars:
        const int count = 7;
        final double gap = 4;
        final double width = (size.width - gap * (count - 1)) / count;
        for (int i = 0; i < count; i++) {
          final double h = size.height * _weights[i] * t;
          final double x = i * (width + gap);
          canvas.drawRRect(
            RRect.fromLTRBR(
              x,
              size.height - h,
              x + width,
              size.height,
              const Radius.circular(2.5),
            ),
            Paint()..shader = accent,
          );
        }
      case _VizKind.heat:
        _cells(
          canvas,
          size,
          rows: 3,
          gap: 3,
          radius: 2,
          colour: colors.accent,
          spread: 0.02,
          t: t,
        );
      case _VizKind.grid:
        _cells(
          canvas,
          size,
          rows: 4,
          gap: 2,
          radius: 1.5,
          colour: colors.accentAlt,
          spread: 0.012,
          t: t,
        );
      case _VizKind.spark:
        final Path path = Path();
        const int points = 7;
        // Inset, so the point riding the end of the line is not half clipped.
        const double edge = 3;
        for (int i = 0; i < points; i++) {
          final double x = edge + (size.width - edge * 2) * i / (points - 1);
          final double y = size.height - size.height * 0.85 * _weights[i] - 2;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        final PathMetric metric = path.computeMetrics().first;
        canvas.drawPath(
          metric.extractPath(0, metric.length * t),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..shader = accent,
        );
        if (t > 0.02) {
          final Tangent? end = metric.getTangentForOffset(metric.length * t);
          if (end != null) {
            canvas.drawCircle(
              end.position,
              3,
              Paint()..color = colors.accentSoft,
            );
          }
        }
    }
  }

  /// A grid of warming cells — the month calendar and the year grid are the
  /// same idea at two densities. The cell is sized from the height, so the
  /// grid always fits its strip however wide the tile turns out to be.
  void _cells(
    Canvas canvas,
    Size size, {
    required int rows,
    required double gap,
    required double radius,
    required Color colour,
    required double spread,
    required double t,
  }) {
    final double cell = (size.height - gap * (rows - 1)) / rows;
    final int cols = ((size.width + gap) / (cell + gap)).floor();
    for (int r = 0; r < rows; r++) {
      for (int col = 0; col < cols; col++) {
        final int i = r * cols + col;
        final double weight = _weights[i % _weights.length];
        final double appear = ((t * 1.7) - i * spread).clamp(0.0, 1.0);
        final double x = col * (cell + gap);
        final double y = r * (cell + gap);
        canvas.drawRRect(
          RRect.fromLTRBR(x, y, x + cell, y + cell, Radius.circular(radius)),
          Paint()
            ..color = colour.withValues(alpha: (0.10 + 0.75 * weight) * appear),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VizPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.kind != kind ||
      oldDelegate.colors.accent != colors.accent;
}

// ---------------------------------------------------------------------------
// 4 · Ready
// ---------------------------------------------------------------------------

class OnboardingReady extends ConsumerWidget {
  const OnboardingReady({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TempoColors c = context.colors;
    final TempoPreferences preferences = ref.watch(preferencesProvider);
    final bool atLogin = ref.watch(startupProvider).value ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _PageHeading(
          title: 'Ready when you are',
          subtitle:
              'Two choices now, and everything else lives in Settings — '
              'including turning this off again.',
        ),
        const SizedBox(height: TempoSpace.lg),
        TempoEntrance(
          index: 1,
          child: _Choice(
            glyph: TempoGlyph.apps,
            title: 'Keep measuring from the tray',
            detail:
                'Closing the window leaves Tempo counting quietly. Turn this '
                'off and closing quits it properly.',
            value: preferences.keepRunningInBackground,
            onChanged: (bool value) => ref
                .read(preferencesProvider.notifier)
                .setKeepRunningInBackground(enabled: value),
          ),
        ),
        const SizedBox(height: TempoSpace.sm),
        TempoEntrance(
          index: 2,
          child: _Choice(
            glyph: TempoGlyph.play,
            title: 'Open Tempo when this computer starts',
            detail:
                'It opens straight into the tray, so a full day is measured '
                'without you thinking about it.',
            value: atLogin,
            onChanged: (bool value) =>
                ref.read(startupProvider.notifier).set(enabled: value),
          ),
        ),
        const SizedBox(height: TempoSpace.md),
        TempoEntrance(
          index: 3,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TempoIcon(TempoGlyph.sparkle, size: 15, color: c.textTertiary),
              const SizedBox(width: TempoSpace.sm),
              Expanded(
                child: Text(
                  'Ctrl+1 to Ctrl+8 jump between the views, Ctrl+B folds the '
                  'sidebar, and the tray icon brings Tempo back at any time. '
                  '${AppInfo.privacyLine}',
                  style: context.typo.bodySmall?.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.glyph,
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final TempoGlyph glyph;
  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Container(
      padding: const EdgeInsets.all(TempoSpace.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TempoRadius.md),
        color: c.glassFill,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TempoRadius.xs),
              color: c.accent.withValues(alpha: 0.12),
              border: Border.all(color: c.accent.withValues(alpha: 0.22)),
            ),
            child: Center(
              child: TempoIcon(glyph, size: 16, color: c.accentSoft),
            ),
          ),
          const SizedBox(width: TempoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: context.typo.titleSmall),
                const SizedBox(height: 1),
                Text(
                  detail,
                  style: context.typo.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: TempoSpace.sm),
          SizedBox(
            width: 132,
            child: TempoSegmented<bool>(
              value: value,
              height: 32,
              onChanged: onChanged,
              segments: const <TempoSegment<bool>>[
                TempoSegment<bool>(value: true, label: 'On'),
                TempoSegment<bool>(value: false, label: 'Off'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return TempoEntrance(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: context.typo.headlineSmall),
          const SizedBox(height: 3),
          Text(subtitle, style: context.typo.bodyMedium),
        ],
      ),
    );
  }
}
