import 'package:flutter/widgets.dart';

/// 4pt spacing scale. Layout only ever uses these steps.
class TempoSpace {
  const TempoSpace._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double huge = 56;
}

/// Corner radii. Tempo is a large-radius product.
class TempoRadius {
  const TempoRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double xxl = 34;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius panel = BorderRadius.all(Radius.circular(xl));
}

/// Fixed chrome dimensions shared by the shell.
class TempoSizes {
  const TempoSizes._();

  static const double titleBar = 32;
  static const double sidebarExpanded = 140;
  static const double sidebarRail = 76;
  static const double navItem = 44;
  static const double navGap = 6;
  static const double captionButton = 46;
  static const double contentMaxWidth = 1240;

  /// Left inset reserved for the macOS window buttons.
  static const double macTrafficLights = 78;

  /// Smallest window Tempo is designed for.
  static const Size minWindow = Size(1120, 700);
  static const Size defaultWindow = Size(1440, 900);
}
