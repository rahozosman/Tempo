import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/tempo_motion.dart';
import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/theme/tempo_typography.dart';
import '../../core/utilities/tempo_format.dart';
import '../../domain/analytics/app_usage.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/awaiting_data.dart';
import '../../shared/widgets/glass/glass_segmented.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/stats/animated_duration.dart';
import '../../shared/widgets/stats/metric_card.dart';
import '../../shared/widgets/stats/metric_grid.dart';
import '../../shared/widgets/tempo_icon.dart';
import 'application_detail_view.dart';
import 'applications_controller.dart';
import 'widgets/application_card.dart';

/// Applications. The ranked list, and the history of whichever application is
/// open, sharing one destination in the sidebar.
///
/// The two live in a navigator of their own rather than a crossfade, which is
/// what lets the mark on a card *fly* into the detail header instead of one
/// screen dissolving into another.
class ApplicationsPage extends ConsumerStatefulWidget {
  const ApplicationsPage({super.key});

  @override
  ConsumerState<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends ConsumerState<ApplicationsPage> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  final HeroController _heroes = HeroController();

  @override
  void initState() {
    super.initState();
    // Arriving with an application already chosen — from Home, from a day
    // panel — opens straight onto it.
    final SelectedApp? open = ref.read(selectedApplicationProvider);
    if (open != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(open));
    }
  }

  void _open(SelectedApp app) {
    final NavigatorState? navigator = _navigator.currentState;
    if (navigator == null) {
      return;
    }
    navigator
      ..popUntil((Route<dynamic> route) => route.isFirst)
      ..push(_detailRoute(app));
  }

  Route<void> _detailRoute(SelectedApp app) => PageRouteBuilder<void>(
    // Long enough for the mark to travel, short enough to feel immediate.
    transitionDuration: TempoMotion.of(context, TempoDuration.page),
    reverseTransitionDuration: TempoMotion.of(context, TempoDuration.base),
    // Opaque: once the detail has settled, the ranked list beneath it stops
    // being painted altogether. The detail view has no background of its own
    // (the shell's ambient backdrop shows through), so a translucent route
    // left the list showing through the detail — two screens at once.
    opaque: true,
    barrierColor: Colors.transparent,
    pageBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
        ) => ApplicationDetailView(selection: app),
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
          Widget child,
        ) {
          final CurvedAnimation curved = CurvedAnimation(
            parent: animation,
            curve: TempoCurve.entrance,
            reverseCurve: TempoCurve.exit,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.018),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
  );

  @override
  Widget build(BuildContext context) {
    ref.listen<SelectedApp?>(selectedApplicationProvider, (
      SelectedApp? previous,
      SelectedApp? next,
    ) {
      final NavigatorState? navigator = _navigator.currentState;
      if (navigator == null) {
        return;
      }
      if (next == null) {
        navigator.popUntil((Route<dynamic> route) => route.isFirst);
      } else {
        _open(next);
      }
    });

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            ref.read(selectedApplicationProvider.notifier).clear(),
      },
      child: Focus(
        autofocus: true,
        child: Navigator(
          key: _navigator,
          observers: <NavigatorObserver>[_heroes],
          onGenerateRoute: (RouteSettings settings) => PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder:
                (
                  BuildContext context,
                  Animation<double> animation,
                  Animation<double> secondary,
                ) => const _RankedApplications(),
            // While a detail is arriving on top, the list steps back out of
            // the way rather than sitting fully lit underneath it; it comes
            // back the same way as the detail leaves.
            transitionsBuilder:
                (
                  BuildContext context,
                  Animation<double> animation,
                  Animation<double> secondary,
                  Widget child,
                ) => FadeTransition(
                  opacity: Tween<double>(begin: 1, end: 0).animate(
                    CurvedAnimation(
                      parent: secondary,
                      curve: TempoCurve.exit,
                      reverseCurve: TempoCurve.entrance,
                    ),
                  ),
                  child: child,
                ),
          ),
        ),
      ),
    );
  }
}

class _RankedApplications extends ConsumerWidget {
  const _RankedApplications();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppsRange range = ref.watch(applicationsRangeProvider);
    final AsyncValue<ApplicationsOverview> overview = ref.watch(
      applicationsOverviewProvider,
    );

    return PageScaffold(
      title: 'Applications',
      subtitle: range.caption,
      trailing: SizedBox(
        width: 264,
        child: TempoSegmented<AppsRange>(
          value: range,
          onChanged: ref.read(applicationsRangeProvider.notifier).set,
          segments: <TempoSegment<AppsRange>>[
            for (final AppsRange value in AppsRange.values)
              TempoSegment<AppsRange>(value: value, label: value.label),
          ],
        ),
      ),
      child: overview.when(
        loading: () => const PageLoading(),
        error: (Object error, StackTrace stack) => ErrorStateView(
          title: 'Unable to read your applications',
          message:
              'Tempo could not open its usage database. Restarting the app '
              'usually clears this.',
          detail: error,
        ),
        data: (ApplicationsOverview data) => data.isEmpty
            ? const AwaitingData(
                glyph: TempoGlyph.apps,
                title: 'No applications recorded yet',
                message:
                    'Each application gets a card with its time, its share of '
                    'the period and how it is trending. Open one for its full '
                    'history.',
              )
            : _RankedList(overview: data),
      ),
    );
  }
}

class _RankedList extends ConsumerWidget {
  const _RankedList({required this.overview});

  final ApplicationsOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AppUsage> apps = overview.apps;
    final AppUsage leader = apps.first;
    final double? change = overview.change;

    return ListView(
      padding: const EdgeInsets.only(bottom: TempoSpace.xl),
      children: <Widget>[
        MetricGrid(
          children: <Widget>[
            MetricCard(
              label: 'Active time',
              glyph: TempoGlyph.clock,
              value: AnimatedDuration(
                value: overview.total,
                style: context.typo.headlineLarge,
              ),
              caption: 'Across every application',
            ),
            MetricCard(
              label: 'Applications',
              glyph: TempoGlyph.apps,
              tone: context.colors.accentAlt,
              value: AnimatedCount(
                value: apps.length,
                style: context.typo.headlineLarge,
              ),
              caption:
                  'Averaging ${TempoFormat.hm(overview.averagePerApp)} each',
            ),
            MetricCard(
              label: 'Most used',
              glyph: TempoGlyph.insights,
              tone: context.colors.accentSoft,
              value: Text(
                leader.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typo.headlineMedium,
              ),
              caption:
                  '${TempoFormat.hm(leader.duration)} · '
                  '${TempoFormat.percent(leader.shareOf(overview.total))} of '
                  'the period',
              onTap: () => openApplication(ref, leader),
            ),
            MetricCard(
              label: 'Compared',
              glyph: change == null || change >= 0
                  ? TempoGlyph.trendUp
                  : TempoGlyph.trendDown,
              value: Text(
                change == null ? '—' : TempoFormat.signedPercent(change),
                style: context.typo.headlineLarge?.copyWith(
                  fontFeatures: TempoTypography.numeric,
                ),
              ),
              caption: change == null
                  ? 'Nothing to compare with yet'
                  : '${TempoFormat.hm(overview.previousTotal)} ${overview.range.comparison}',
            ),
          ],
        ),
        const SizedBox(height: TempoSpace.lg),
        for (int i = 0; i < apps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: TempoSpace.sm),
            child: ApplicationCard(
              rank: i + 1,
              usage: apps[i],
              total: overview.total,
              index: i,
              onTap: () => openApplication(ref, apps[i]),
            ),
          ),
      ],
    );
  }
}
