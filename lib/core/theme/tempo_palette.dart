import 'package:flutter/material.dart';

import 'tempo_colors.dart';

/// The series palette used to tell applications apart in charts and lists.
///
/// Every tone is drawn from the product identity — blue through purple to
/// violet — so a ranked list stays calm instead of turning into a rainbow.
class TempoPalette {
  const TempoPalette._();

  static List<Color> series(TempoColors c) => <Color>[
    c.accent,
    Color.lerp(c.accent, c.accentAlt, 0.5)!,
    c.accentAlt,
    Color.lerp(c.accentAlt, c.accentSoft, 0.55)!,
    c.accentSoft,
    Color.lerp(c.accentSoft, c.accent, 0.4)!,
  ];

  /// A stable tone for an application. Uses an FNV-1a hash rather than
  /// [Object.hashCode] so an app keeps its colour between launches.
  static Color toneFor(TempoColors c, String seed) {
    final List<Color> tones = series(c);
    return tones[_hash(seed) % tones.length];
  }

  /// A gradient for one series tone, always ending a little brighter.
  static LinearGradient gradientFor(Color tone) => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[
      tone.withValues(alpha: 0.85),
      Color.lerp(tone, const Color(0xFFFFFFFF), 0.22)!,
    ],
  );

  static int _hash(String value) {
    int hash = 0x811C9DC5;
    for (int i = 0; i < value.length; i++) {
      hash ^= value.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }
}
