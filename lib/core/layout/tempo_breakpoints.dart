/// Desktop breakpoints. Tempo targets 1280x720 through 2560x1440.
class TempoBreakpoints {
  const TempoBreakpoints._();

  /// Below this width the sidebar becomes an icon rail.
  static const double rail = 1180;

  /// Below this width the page gutters tighten.
  static const double compact = 1400;

  static bool useRail(double width) => width < rail;

  static double gutter(double width) => width < compact ? 28 : 40;
}
