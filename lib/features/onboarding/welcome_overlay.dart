import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_info.dart';
import '../../core/motion/tempo_animations.dart';
import '../../core/motion/tempo_motion.dart';
import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../data/analytics/analytics_providers.dart';
import '../../data/database/tempo_database.dart';
import '../../platform/usage_tracking/usage_tracking_platform.dart';
import '../../platform/usage_tracking/usage_tracking_providers.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/tempo_icon.dart';
import '../../shared/widgets/tempo_mark.dart';
import '../settings/preferences_controller.dart';
import 'onboarding_controller.dart';
import 'onboarding_pages.dart';

/// The first run: four pages that say what Tempo measures, what it refuses to
/// measure, what you get for it, and how it should behave — before a single
/// second is recorded.
///
/// Both endings are honoured. "Not now" leaves the app fully usable and
/// records nothing until tracking is turned on in Settings.
class WelcomeOverlay extends ConsumerStatefulWidget {
  const WelcomeOverlay({super.key});

  @override
  ConsumerState<WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends ConsumerState<WelcomeOverlay> {
  static const int _pages = 4;

  /// Tall enough for the longest page, so the card never resizes between
  /// them: the content crossfades inside a frame that holds still.
  static const double _stageHeight = 396;

  int _page = 0;
  bool _forward = true;

  /// The shell below also autofocuses, and whichever node wins would own the
  /// arrow keys. The overlay takes the focus back once it is on screen.
  final FocusNode _keys = FocusNode(debugLabel: 'onboarding');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _keys.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _keys.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    final int next = page.clamp(0, _pages - 1);
    if (next == _page) {
      return;
    }
    setState(() {
      _forward = next > _page;
      _page = next;
    });
  }

  void _finish({required bool tracking}) {
    ref.read(preferencesProvider.notifier).setTrackingEnabled(
      enabled: tracking,
    );
    ref.read(onboardingCompletedProvider.notifier).complete();
  }

  Widget _pageFor(int index) => switch (index) {
    0 => const OnboardingWelcome(),
    1 => const OnboardingMeasures(),
    2 => const OnboardingFeatures(),
    _ => const OnboardingReady(),
  };

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final UsageTrackingPlatform platform = ref.watch(
      usageTrackingPlatformProvider,
    );
    final TempoDatabase? database = ref.watch(databaseProvider);
    final bool last = _page == _pages - 1;
    final bool canMeasure = platform.isSupported && database != null;

    return Listener(
      // The app behind is real and running; nothing there should be clickable
      // until this has been answered.
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              c.backdrop.withValues(alpha: 0.965),
              c.backdropEdge.withValues(alpha: 0.99),
            ],
          ),
        ),
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _goTo(_page + 1),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _goTo(_page - 1),
            const SingleActivator(LogicalKeyboardKey.enter): () {
              if (last) {
                if (canMeasure) {
                  _finish(tracking: true);
                }
              } else {
                _goTo(_page + 1);
              }
            },
          },
          child: Focus(
            focusNode: _keys,
            autofocus: true,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: TempoSpace.xl,
                  vertical: TempoSpace.lg,
                ),
                child: TempoEntrance(
                  rise: 20,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: GlassCard(
                      hoverLift: false,
                      radius: TempoRadius.xxl,
                      padding: const EdgeInsets.fromLTRB(
                        TempoSpace.huge - TempoSpace.xs,
                        TempoSpace.xl,
                        TempoSpace.huge - TempoSpace.xs,
                        TempoSpace.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _Header(
                            onSkip: last ? null : () => _goTo(_pages - 1),
                          ),
                          const SizedBox(height: TempoSpace.lg),
                          SizedBox(
                            height: _stageHeight,
                            child: AnimatedSwitcher(
                              duration: TempoMotion.of(
                                context,
                                TempoDuration.page,
                              ),
                              switchInCurve: TempoCurve.entrance,
                              switchOutCurve: TempoCurve.exit,
                              layoutBuilder:
                                  (
                                    Widget? current,
                                    List<Widget> previous,
                                  ) => Stack(
                                    fit: StackFit.expand,
                                    children: <Widget>[...previous, ?current],
                                  ),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    final bool entering =
                                        child.key == ValueKey<int>(_page);
                                    final double from =
                                        (entering ? 1 : -1) *
                                        (_forward ? 0.045 : -0.045);
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position:
                                            Tween<Offset>(
                                              begin: Offset(from, 0),
                                              end: Offset.zero,
                                            ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                              child: KeyedSubtree(
                                key: ValueKey<int>(_page),
                                child: _pageFor(_page),
                              ),
                            ),
                          ),
                          const SizedBox(height: TempoSpace.lg),
                          Container(height: 1, color: c.border),
                          const SizedBox(height: TempoSpace.md),
                          _Footer(
                            page: _page,
                            pages: _pages,
                            last: last,
                            canMeasure: canMeasure,
                            onDot: _goTo,
                            onBack: () => _goTo(_page - 1),
                            onNext: () => _goTo(_page + 1),
                            onFinish: _finish,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSkip});

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return Row(
      children: <Widget>[
        const TempoMark(size: 24),
        const SizedBox(width: TempoSpace.sm),
        Text(
          AppInfo.name,
          style: context.typo.titleSmall?.copyWith(letterSpacing: 0.4),
        ),
        const SizedBox(width: TempoSpace.sm),
        Text(
          'First run',
          style: context.typo.labelSmall?.copyWith(color: c.textTertiary),
        ),
        const Spacer(),
        AnimatedOpacity(
          duration: TempoMotion.of(context, TempoDuration.quick),
          opacity: onSkip == null ? 0 : 1,
          child: GlassButton(
            label: 'Skip',
            compact: true,
            style: GlassButtonStyle.quiet,
            onPressed: onSkip,
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.page,
    required this.pages,
    required this.last,
    required this.canMeasure,
    required this.onDot,
    required this.onBack,
    required this.onNext,
    required this.onFinish,
  });

  final int page;
  final int pages;
  final bool last;
  final bool canMeasure;
  final ValueChanged<int> onDot;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final void Function({required bool tracking}) onFinish;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < pages; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _Dot(active: i == page, onTap: () => onDot(i)),
          ),
        const Spacer(),
        if (page > 0) ...<Widget>[
          GlassButton(
            label: 'Back',
            glyph: TempoGlyph.chevronLeft,
            style: GlassButtonStyle.quiet,
            onPressed: onBack,
          ),
          const SizedBox(width: TempoSpace.xs),
        ],
        if (last) ...<Widget>[
          GlassButton(
            label: 'Not now',
            onPressed: () => onFinish(tracking: false),
          ),
          const SizedBox(width: TempoSpace.xs),
          GlassButton(
            label: 'Start measuring',
            glyph: TempoGlyph.play,
            style: GlassButtonStyle.primary,
            onPressed: canMeasure ? () => onFinish(tracking: true) : null,
          ),
        ] else
          GlassButton(
            label: 'Continue',
            glyph: TempoGlyph.chevronRight,
            style: GlassButtonStyle.primary,
            onPressed: onNext,
          ),
      ],
    );
  }
}

/// The page indicator. The current page is a lit capsule; the rest are quiet
/// dots you can still click.
class _Dot extends StatelessWidget {
  const _Dot({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    return HoverBuilder(
      onTap: onTap,
      builder: (BuildContext context, bool hovered) => AnimatedContainer(
        duration: TempoMotion.of(context, TempoDuration.base),
        curve: TempoCurve.emphasized,
        width: active ? 22 : 7,
        height: 7,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: active ? context.tempo.accentGradient : null,
          color: active
              ? null
              : (hovered ? c.textTertiary : c.textTertiary.withValues(
                  alpha: 0.35,
                )),
          boxShadow: active ? context.tempo.accentGlow(0.6) : null,
        ),
      ),
    );
  }
}
