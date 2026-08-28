import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/tempo_breakpoints.dart';
import '../../core/motion/tempo_animations.dart';
import '../../core/theme/tempo_theme.dart';
import '../../shared/widgets/ambient_background.dart';
import '../about/about_page.dart';
import '../applications/applications_page.dart';
import '../dashboard/home_page.dart';
import '../insights/insights_page.dart';
import '../month/month_page.dart';
import '../../platform/desktop/desktop_integration.dart';
import '../../platform/usage_tracking/usage_tracking_providers.dart';
import '../onboarding/onboarding_controller.dart';
import '../onboarding/welcome_overlay.dart';
import '../navigation/nav_destination.dart';
import '../navigation/navigation_controller.dart';
import '../settings/settings_page.dart';
import '../today/today_page.dart';
import '../week/week_page.dart';
import '../year/year_page.dart';
import 'shell_controller.dart';
import 'widgets/tempo_sidebar.dart';
import 'widgets/tempo_title_bar.dart';

/// The desktop shell: ambient room, permanent sidebar, custom title bar and
/// the page host that crossfades between destinations.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const List<LogicalKeyboardKey> _digits = <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  static Widget _pageFor(TempoSection section) => switch (section) {
    TempoSection.home => const HomePage(),
    TempoSection.today => const TodayPage(),
    TempoSection.applications => const ApplicationsPage(),
    TempoSection.week => const WeekPage(),
    TempoSection.month => const MonthPage(),
    TempoSection.year => const YearPage(),
    TempoSection.insights => const InsightsPage(),
    TempoSection.about => const AboutPage(),
    TempoSection.settings => const SettingsPage(),
  };

  /// Cmd/Ctrl+1…8 jump to a destination, Cmd/Ctrl+, opens Settings and
  /// Cmd/Ctrl+B folds the sidebar into its rail.
  Map<ShortcutActivator, VoidCallback> _shortcuts(WidgetRef ref) {
    final Map<ShortcutActivator, VoidCallback> bindings =
        <ShortcutActivator, VoidCallback>{};

    void bind(LogicalKeyboardKey key, VoidCallback action) {
      bindings[SingleActivator(key, control: true)] = action;
      bindings[SingleActivator(key, meta: true)] = action;
    }

    final int count = kDestinations.length < _digits.length
        ? kDestinations.length
        : _digits.length;
    for (int i = 0; i < count; i++) {
      final int index = i;
      bind(
        _digits[i],
        () => ref.read(navigationProvider.notifier).select(index),
      );
    }
    bind(
      LogicalKeyboardKey.comma,
      () => ref
          .read(navigationProvider.notifier)
          .selectSection(TempoSection.settings),
    );
    bind(
      LogicalKeyboardKey.keyB,
      () => ref.read(sidebarCollapsedProvider.notifier).toggle(),
    );
    return bindings;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching the tracker starts it with the shell and stops it with the
    // shell, so nothing measures in the background of a closed window.
    ref.watch(usageTrackerProvider);

    final int destination = ref.watch(navigationProvider);
    final TempoSection section = kDestinations[destination].section;
    final bool foldedByUser = ref.watch(sidebarCollapsedProvider);

    return Scaffold(
      backgroundColor: context.colors.backdrop,
      body: CallbackShortcuts(
        bindings: _shortcuts(ref),
        child: Focus(
          autofocus: true,
          child: Stack(
            // The shell fills whatever the Scaffold gives it. Every child here
            // is positioned, and Scaffold hands its body loose constraints, so
            // without this the Stack would shrink to nothing and clip the whole
            // interface away.
            fit: StackFit.expand,
            children: <Widget>[
              const Positioned.fill(child: AmbientBackground()),
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool collapsed =
                        foldedByUser ||
                        TempoBreakpoints.useRail(constraints.maxWidth);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TempoSidebar(collapsed: collapsed),
                        Expanded(
                          child: FocusTraversalGroup(
                            child: TempoPageSwitcher(
                              order: destination,
                              child: KeyedSubtree(
                                key: ValueKey<TempoSection>(section),
                                child: _pageFor(section),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // Above the app, below the title bar: the window can still be
              // moved and closed while the first run is showing.
              if (!ref.watch(onboardingCompletedProvider))
                const Positioned.fill(child: WelcomeOverlay()),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TempoTitleBar(),
              ),
              // Draws nothing: the tray, the close behaviour and the
              // notifications live here so they last as long as the app does.
              const DesktopIntegration(),
            ],
          ),
        ),
      ),
    );
  }
}
