import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the user has asked for the icon rail. Narrow windows collapse the
/// sidebar on their own; this is the manual override on top of that.
class SidebarController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void set(bool collapsed) => state = collapsed;
}

final NotifierProvider<SidebarController, bool> sidebarCollapsedProvider =
    NotifierProvider<SidebarController, bool>(SidebarController.new);
