import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/models/traffic_record.dart';

/// `total_vehicles` over the last hour for one intersection.
///
/// Deliberately drawn in the chrome colour, not a congestion hue: this is a
/// volume trend, not a level, and the four semantic colours are reserved for
/// saying how bad it is.
class HistoryChart extends StatelessWidget {
  const HistoryChart({
    super.key,
    required this.records,
    required this.now,
    this.window = const Duration(hours: 1),
  });

  /// Oldest first, as the API returns them.
  final List<TrafficRecord> records;
  final DateTime now;
  final Duration window;

  static const double height = 132;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (records.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Belum ada riwayat satu jam terakhir.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // x is minutes before now, so the newest point sits at 0 on the right and
    // the axis reads the way an operator says it: "fifteen minutes ago".
    final spots = [
      for (final record in records)
        FlSpot(
          -now.difference(record.ts).inSeconds / 60,
          record.totalVehicles.toDouble(),
        ),
    ];
    final peak = records
        .map((r) => r.totalVehicles)
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: -window.inMinutes.toDouble(),
          maxX: 0,
          minY: 0,
          // Never a flat line pinned to the top: an all-zero hour still needs a
          // readable axis, and a busy one needs headroom above the peak.
          maxY: (peak * 1.2).clamp(4, double.infinity),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: scheme.primary,
              barWidth: 2,
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: scheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: scheme.outlineVariant, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) => Text(
                  value % 1 == 0 ? '${value.toInt()}' : '',
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 15,
                reservedSize: 22,
                getTitlesWidget: (value, meta) => Text(
                  value == 0 ? 'kini' : '${-value.toInt()}m',
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
