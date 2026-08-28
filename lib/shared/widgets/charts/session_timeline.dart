import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion/tempo_animations.dart';
import '../../../core/motion/tempo_motion.dart';
import '../../../core/theme/tempo_colors.dart';
import '../../../core/theme/tempo_metrics.dart';
import '../../../core/theme/tempo_palette.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/utilities/tempo_format.dart';
import '../../../domain/tracking/usage_session.dart';

/// The day as it actually happened: every recorded stretch in its own place on
/// the clock, in the colour its application wears everywhere else.
///
/// This is the one view drawn from the sessions themselves rather than from a
/// summary, so it is also how you can see that the engine measured what you
/// remember doing. Gaps are real: they are time that belonged to no
/// application — away from the machine, or idle.
class SessionTimeline extends StatelessWidget {
  const SessionTimeline({
    super.key,
    required this.sessions,
    required this.date,
    this.height = 58,
    this.onOpen,
  });

  final List<UsageSession> sessions;

  /// Midnight of the day being drawn.
  final DateTime date;

  final double height;

  /// Called with an application id when one of its blocks is chosen.
  final void Function(UsageSession session)? onOpen;

  /// Anything narrower would be invisible; a two-minute stretch still deserves
  /// a mark.
  static const double _minimumWidth = 3;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    if (sessions.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No sessions recorded for this day.',
            style: context.typo.bodySmall,
          ),
        ),
      );
    }

    // The window runs from the first stretch to the last, rounded outwards to
    // the hour, so a day that started at nine does not waste a third of the
    // strip on an empty morning.
    final DateTime first = sessions.first.start;
    final DateTime last = sessions
        .map((UsageSession s) => s.end)
        .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);
    final DateTime from = DateTime(date.year, date.month, date.day, first.hour);
    final DateTime to = DateTime(
      date.year,
      date.month,
      date.day,
      math.min(23, last.hour) + 1,
    );
    final int span = math.max(1, to.difference(from).inSeconds);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        double xOf(DateTime moment) =>
            (moment.difference(from).inSeconds / span).clamp(0.0, 1.0) * width;

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: TempoMotion.of(
            context,
            const Duration(milliseconds: 1000),
          ),
          curve: TempoCurve.entrance,
          builder: (BuildContext context, double t, Widget? child) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: height,
                child: Stack(
                  children: <Widget>[
                    // The lane the day sits in, and an hour mark every hour.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(TempoRadius.sm),
                          color: c.glassFill.withValues(alpha: 0.06),
                          border: Border.all(color: c.border),
                        ),
                      ),
                    ),
                    for (
                      DateTime hour = from.add(const Duration(hours: 1));
                      hour.isBefore(to);
                      hour = hour.add(const Duration(hours: 1))
                    )
                      Positioned(
                        left: xOf(hour),
                        top: 6,
                        bottom: 6,
                        child: SizedBox(
                          width: 1,
                          child: ColoredBox(
                            color: c.border.withValues(alpha: c.border.a * 0.7),
                          ),
                        ),
                      ),
                    for (final UsageSession session in sessions)
                      _Block(
                        session: session,
                        left: xOf(session.start),
                        width: math.max(
                          _minimumWidth,
                          xOf(session.end) - xOf(session.start),
                        ),
                        progress: t,
                        onOpen: onOpen,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: TempoSpace.xs),
              Row(
                children: <Widget>[
                  Text(
                    TempoFormat.hourLabel(from.hour),
                    style: context.typo.bodySmall?.copyWith(
                      fontSize: 11,
                      color: c.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    TempoFormat.count(sessions.length, 'session'),
                    style: context.typo.bodySmall?.copyWith(
                      fontSize: 11,
                      color: c.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    TempoFormat.hourLabel(to.hour % 24),
                    style: context.typo.bodySmall?.copyWith(
                      fontSize: 11,
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.session,
    required this.left,
    required this.width,
    required this.progress,
    this.onOpen,
  });

  final UsageSession session;
  final double left;
  final double width;
  final double progress;
  final void Function(UsageSession session)? onOpen;

  @override
  Widget build(BuildContext context) {
    final TempoColors c = context.colors;
    final Color tone = TempoPalette.toneFor(c, session.applicationId);

    return Positioned(
      left: left,
      top: 5,
      bottom: 5,
      width: width,
      child: Tooltip(
        message:
            '${session.applicationName}\n'
            '${TempoFormat.clock(session.start)} – '
            '${TempoFormat.clock(session.end)}\n'
            '${TempoFormat.hm(session.duration)}',
        waitDuration: const Duration(milliseconds: 160),
        child: HoverBuilder(
          onTap: onOpen == null ? null : () => onOpen!(session),
          builder: (BuildContext context, bool hovered) => Align(
            alignment: Alignment.centerLeft,
            // Blocks grow out of the clock rather than fading in on top of it.
            child: FractionallySizedBox(
              widthFactor: progress,
              child: AnimatedContainer(
                duration: TempoMotion.of(context, TempoDuration.quick),
                curve: TempoCurve.gentle,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: TempoPalette.gradientFor(tone),
                  border: hovered
                      ? Border.all(color: c.textPrimary.withValues(alpha: 0.7))
                      : null,
                  boxShadow: hovered ? context.tempo.glowOf(tone, 0.7) : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
