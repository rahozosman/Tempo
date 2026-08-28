import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_info.dart';
import '../../core/motion/tempo_animations.dart';
import '../../core/platform/tempo_platform.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/tempo_icon.dart';

/// About: who made Tempo, what it measures, and how to get the most out of it.
///
/// A destination of its own rather than a line in Settings, because it is the
/// one page that answers questions instead of changing something.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'About',
      subtitle: 'The person behind Tempo, and how to use it.',
      child: ListView(
        padding: const EdgeInsets.only(bottom: TempoSpace.xl),
        children: const <Widget>[
          TempoEntrance(child: _DeveloperCard()),
          SizedBox(height: TempoSpace.md),
          TempoEntrance(index: 1, child: _AboutAppCard()),
          SizedBox(height: TempoSpace.md),
          TempoEntrance(index: 2, child: _HowToUseCard()),
          SizedBox(height: TempoSpace.md),
          TempoEntrance(index: 3, child: _ShortcutsCard()),
        ],
      ),
    );
  }
}

/// The name plate: monogram in the product gradient, the name, and an address
/// written out so it can be read and copied as well as clicked.
class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard();

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final TempoTheme theme = context.tempo;
    return GlassCard(
      hoverLift: false,
      padding: const EdgeInsets.all(TempoSpace.lg),
      child: Row(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TempoRadius.lg),
              gradient: theme.accentGradient,
              boxShadow: theme.accentGlow(0.9),
            ),
            child: Center(
              child: Text(
                'RO',
                style: context.typo.headlineSmall?.copyWith(
                  color: theme.isDark
                      ? const Color(0xFF06081A)
                      : const Color(0xFFFFFFFF),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          const SizedBox(width: TempoSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(AppInfo.developer, style: context.typo.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  'Developer — designed and built ${AppInfo.name}.',
                  style: context.typo.bodyMedium,
                ),
                const SizedBox(height: TempoSpace.xs),
                SelectableText(
                  AppInfo.developerEmail,
                  style: context.typo.bodyMedium?.copyWith(
                    color: c.accentSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: TempoSpace.md),
          GlassButton(
            label: 'Write',
            glyph: TempoGlyph.sparkle,
            style: GlassButtonStyle.primary,
            onPressed: () => unawaited(
              launchUrl(
                Uri(scheme: 'mailto', path: AppInfo.developerEmail),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the product is, in the same three promises the first run makes.
class _AboutAppCard extends StatelessWidget {
  const _AboutAppCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      hoverLift: false,
      padding: const EdgeInsets.all(TempoSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CardTitle(
            glyph: TempoGlyph.clock,
            title: '${AppInfo.name} · ${AppInfo.tagline}',
            detail:
                'Tempo keeps a quiet record of where your hours actually go: '
                'which application is in front of you, and for how long. '
                'Version ${AppInfo.version}, running on '
                '${TempoPlatform.isMacOS ? 'macOS' : 'Windows'}.',
          ),
          const SizedBox(height: TempoSpace.md),
          const _Point(
            glyph: TempoGlyph.today,
            title: 'It measures one thing',
            detail:
                'The application in front, and the time it holds. Time away '
                'from the keyboard is counted separately and belongs to no '
                'application.',
          ),
          const _Point(
            glyph: TempoGlyph.lock,
            title: 'It reads nothing else, and sends nothing',
            detail:
                'No window titles, no documents, no addresses, no screenshots. '
                'No account, and no network request of its own.',
          ),
          const _Point(
            glyph: TempoGlyph.year,
            title: 'It all stays in one file here',
            detail:
                'Your history lives in a single database on this computer. '
                'Export it or delete it whenever you like, from Settings.',
            last: true,
          ),
        ],
      ),
    );
  }
}

/// The five things worth knowing on the first day.
class _HowToUseCard extends StatelessWidget {
  const _HowToUseCard();

  static const List<List<String>> _steps = <List<String>>[
    <String>[
      'Leave it running',
      'Tempo measures while it is open, and keeps measuring from the tray '
          'when you close the window. Turn that off in Settings if you would '
          'rather closing quit it.',
    ],
    <String>[
      'Read today first',
      'Home is the shape of the day so far; Today breaks it down hour by '
          'hour and application by application.',
    ],
    <String>[
      'Set a goal you believe',
      'Settings · Screen time sets the daily goal the ring on Today measures '
          'against, and the point at which Tempo says something.',
    ],
    <String>[
      'Step back for the pattern',
      'Week, Month and Year are the same measurement from further away. '
          'Insights turns them into plain sentences.',
    ],
    <String>[
      'Take it with you',
      'Insights can share a report as an image or text, and Settings can '
          'export the raw history — both only when you ask.',
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return GlassCard(
      hoverLift: false,
      padding: const EdgeInsets.all(TempoSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _CardTitle(
            glyph: TempoGlyph.sparkle,
            title: 'How to use it',
            detail: 'Five minutes of setup, then it looks after itself.',
          ),
          const SizedBox(height: TempoSpace.md),
          for (int i = 0; i < _steps.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == _steps.length - 1 ? 0 : TempoSpace.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accent.withValues(alpha: 0.14),
                      border: Border.all(
                        color: c.accent.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: context.typo.labelMedium?.copyWith(
                          color: c.accentSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: TempoSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(_steps[i][0], style: context.typo.titleSmall),
                        const SizedBox(height: 2),
                        Text(_steps[i][1], style: context.typo.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Everything the keyboard can do, in the order the sidebar has them.
class _ShortcutsCard extends StatelessWidget {
  const _ShortcutsCard();

  static const List<List<String>> _keys = <List<String>>[
    <String>['Ctrl + 1 … 9', 'Jump straight to a section'],
    <String>['Ctrl + B', 'Fold the sidebar into its rail'],
    <String>['Ctrl + ,', 'Open Settings'],
  ];

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return GlassCard(
      hoverLift: false,
      padding: const EdgeInsets.all(TempoSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _CardTitle(
            glyph: TempoGlyph.settings,
            title: 'Keyboard',
            detail: 'On macOS, Command does the same as Ctrl.',
          ),
          const SizedBox(height: TempoSpace.md),
          for (int i = 0; i < _keys.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == _keys.length - 1 ? 0 : TempoSpace.sm,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TempoSpace.sm,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(TempoRadius.xs),
                      color: c.glassFill,
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      _keys[i][0],
                      style: context.typo.labelMedium?.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: TempoSpace.md),
                  Expanded(
                    child: Text(_keys[i][1], style: context.typo.bodySmall),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A card's own heading: the glyph tile, the line, and what it means.
class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.glyph,
    required this.title,
    required this.detail,
  });

  final TempoGlyph glyph;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TempoRadius.sm),
            color: c.accent.withValues(alpha: 0.12),
            border: Border.all(color: c.accent.withValues(alpha: 0.22)),
          ),
          child: Center(child: TempoIcon(glyph, size: 18, color: c.accentSoft)),
        ),
        const SizedBox(width: TempoSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: context.typo.titleMedium),
              const SizedBox(height: 2),
              Text(detail, style: context.typo.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// One promise, in the same shape the first run uses.
class _Point extends StatelessWidget {
  const _Point({
    required this.glyph,
    required this.title,
    required this.detail,
    this.last = false,
  });

  final TempoGlyph glyph;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : TempoSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: TempoIcon(glyph, size: 15, color: c.textTertiary),
          ),
          const SizedBox(width: TempoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: context.typo.titleSmall),
                const SizedBox(height: 1),
                Text(detail, style: context.typo.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
