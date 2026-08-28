import 'package:flutter/material.dart';

import '../../../core/theme/tempo_metrics.dart';

/// Lays statistic cards out in equal columns, folding from four across to two
/// and then to one as the window narrows. Cards in a row always match height.
class MetricGrid extends StatelessWidget {
  const MetricGrid({
    super.key,
    required this.children,
    this.spacing = TempoSpace.md,
    this.wideBreakpoint = 900,
    this.mediumBreakpoint = 560,
    this.maxPerRow = 4,
  });

  final List<Widget> children;
  final double spacing;
  final double wideBreakpoint;
  final double mediumBreakpoint;

  /// Columns at the widest layout. Six cards read better as two rows of three.
  final int maxPerRow;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int perRow = constraints.maxWidth >= wideBreakpoint
            ? (children.length < maxPerRow ? children.length : maxPerRow)
            : (constraints.maxWidth >= mediumBreakpoint ? 2 : 1);

        final List<Widget> rows = <Widget>[];
        for (int start = 0; start < children.length; start += perRow) {
          final int end = (start + perRow) > children.length
              ? children.length
              : start + perRow;
          final List<Widget> row = <Widget>[];
          for (int i = start; i < end; i++) {
            if (i != start) {
              row.add(SizedBox(width: spacing));
            }
            row.add(Expanded(child: children[i]));
          }
          // Keep the last row aligned with the ones above it.
          for (int filler = end - start; filler < perRow; filler++) {
            row
              ..add(SizedBox(width: spacing))
              ..add(const Expanded(child: SizedBox.shrink()));
          }
          if (rows.isNotEmpty) {
            rows.add(SizedBox(height: spacing));
          }
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: row,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}
