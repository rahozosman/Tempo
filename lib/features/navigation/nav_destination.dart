import 'package:flutter/foundation.dart';

import '../../shared/widgets/tempo_icon.dart';

/// Every place Tempo can show.
enum TempoSection {
  home,
  today,
  applications,
  week,
  month,
  year,
  insights,
  about,
  settings,
}

@immutable
class NavDestination {
  const NavDestination({
    required this.section,
    required this.label,
    required this.glyph,
    required this.hint,
  });

  final TempoSection section;
  final String label;
  final TempoGlyph glyph;

  /// Shown as the tooltip when the sidebar is collapsed to a rail.
  final String hint;
}

/// Sidebar order. This list is the single source of truth for navigation:
/// the sidebar, the keyboard shortcuts and the page host all read it.
const List<NavDestination> kDestinations = <NavDestination>[
  NavDestination(
    section: TempoSection.home,
    label: 'Home',
    glyph: TempoGlyph.home,
    hint: 'Home dashboard',
  ),
  NavDestination(
    section: TempoSection.today,
    label: 'Today',
    glyph: TempoGlyph.today,
    hint: 'Today in detail',
  ),
  NavDestination(
    section: TempoSection.applications,
    label: 'Applications',
    glyph: TempoGlyph.apps,
    hint: 'Applications',
  ),
  NavDestination(
    section: TempoSection.week,
    label: 'Week',
    glyph: TempoGlyph.week,
    hint: 'This week',
  ),
  NavDestination(
    section: TempoSection.month,
    label: 'Month',
    glyph: TempoGlyph.month,
    hint: 'This month',
  ),
  NavDestination(
    section: TempoSection.year,
    label: 'Year',
    glyph: TempoGlyph.year,
    hint: 'Yearly activity',
  ),
  NavDestination(
    section: TempoSection.insights,
    label: 'Insights',
    glyph: TempoGlyph.insights,
    hint: 'Insights',
  ),
  NavDestination(
    section: TempoSection.about,
    label: 'About',
    glyph: TempoGlyph.info,
    hint: 'About Tempo',
  ),
  NavDestination(
    section: TempoSection.settings,
    label: 'Settings',
    glyph: TempoGlyph.settings,
    hint: 'Settings',
  ),
];
