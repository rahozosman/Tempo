import 'package:flutter/material.dart';

import '../../core/theme/tempo_colors.dart';
import '../../core/theme/tempo_palette.dart';
import '../../core/theme/tempo_theme.dart';

/// The stand-in mark for an application.
///
/// Until the platform layer can hand over a real icon from the executable or
/// the app bundle, an application is shown as its initial on a tile tinted with
/// the tone it keeps everywhere else in the app.
class AppGlyph extends StatelessWidget {
  const AppGlyph({
    super.key,
    required this.id,
    required this.name,
    this.size = 36,
  });

  final String id;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final Color tone = TempoPalette.toneFor(c, id);
    final String initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            tone.withValues(alpha: 0.30),
            tone.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      child: Center(
        child: Text(
          initial,
          style: context.typo.titleMedium?.copyWith(
            color: Color.lerp(tone, c.textPrimary, 0.35),
            fontSize: size * 0.42,
            height: 1,
          ),
        ),
      ),
    );
  }
}
