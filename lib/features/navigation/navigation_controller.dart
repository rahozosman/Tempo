import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nav_destination.dart';

/// Which sidebar destination is showing. Held as an index so the sidebar
/// indicator can animate to a position without a lookup.
class NavigationController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) {
    if (index < 0 || index >= kDestinations.length || index == state) {
      return;
    }
    state = index;
  }

  void selectSection(TempoSection section) => select(
    kDestinations.indexWhere(
      (NavDestination destination) => destination.section == section,
    ),
  );
}

final NotifierProvider<NavigationController, int> navigationProvider =
    NotifierProvider<NavigationController, int>(NavigationController.new);
