import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/tempo_metrics.dart';
import '../../core/theme/tempo_theme.dart';
import '../../core/theme/tempo_typography.dart';
import '../../core/utilities/tempo_format.dart';
import 'glass/glass_surface.dart';
import 'tempo_icon.dart';

/// The wall clock in the Home header. It keeps the dashboard feeling live
/// without anything moving quickly.
class LiveClock extends StatefulWidget {
  const LiveClock({super.key});

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (Timer _) {
      final DateTime now = DateTime.now();
      if (!mounted || now.minute == _now.minute) {
        return;
      }
      setState(() => _now = now);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: TempoRadius.md,
      padding: const EdgeInsets.symmetric(
        horizontal: TempoSpace.sm + 2,
        vertical: TempoSpace.xs + 1,
      ),
      shadows: const <BoxShadow>[],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TempoIcon(
            TempoGlyph.clock,
            size: 15,
            color: context.colors.textSecondary,
          ),
          const SizedBox(width: TempoSpace.xs),
          Text(
            TempoFormat.clock(_now),
            style: context.typo.labelLarge?.copyWith(
              fontFeatures: TempoTypography.numeric,
            ),
          ),
        ],
      ),
    );
  }
}
