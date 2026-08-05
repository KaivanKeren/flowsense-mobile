import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/history.dart';
import '../../domain/lane_label.dart';

/// Sixty minutes of one intersection, one bar per minute.
///
/// Two encodings from two different sources, deliberately: **height is the
/// vehicle count, colour is the worst lane's level.** Taking the colour from
/// the total instead would paint the chart green while one approach was
/// completely blocked. The readout line above names the lane responsible, so
/// the pairing reads as intentional rather than confusing.
class HistoryChart extends StatefulWidget {
  const HistoryChart({
    super.key,
    required this.buckets,
    required this.lanes,
    required this.selectedLane,
    required this.onLaneChanged,
  });

  final List<HistoryBucket> buckets;

  /// Lane keys in the intersection's declared order.
  final List<String> lanes;

  /// The lane the chart is filtered to, or null for every approach.
  final String? selectedLane;
  final ValueChanged<String?> onLaneChanged;

  static const double chartHeight = 72;

  /// Height of the stub drawn for a minute with no data. It sits at the base
  /// and is never joined to its neighbours.
  static const double gapStubHeight = 3;

  @override
  State<HistoryChart> createState() => _HistoryChartState();
}

class _HistoryChartState extends State<HistoryChart> {
  /// Index of the bar the user tapped, or null for "the latest reading".
  int? _touched;

  @override
  void didUpdateWidget(HistoryChart old) {
    super.didUpdateWidget(old);
    // A shorter series after a lane switch must not leave the cursor dangling
    // past the end of the list.
    if (_touched != null && _touched! >= widget.buckets.length) {
      _touched = null;
    }
  }

  HistoryBucket? get _readout {
    if (widget.buckets.isEmpty) return null;
    if (_touched != null) return widget.buckets[_touched!];
    final last = widget.buckets.lastIndexWhere((b) => b.hasData);
    return last < 0 ? widget.buckets.last : widget.buckets[last];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final surfaces = FlowSurfaces.of(context);
    final summary = historySummary(widget.buckets);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('60 menit terakhir', style: text.titleMedium),
        const SizedBox(height: 4),
        _Readout(bucket: _readout, lane: widget.selectedLane),
        const SizedBox(height: 8),
        _Bars(
          buckets: widget.buckets,
          touched: _touched,
          onTouch: (i) => setState(() => _touched = i),
        ),
        const SizedBox(height: 6),
        _AxisLabels(labels: historyAxisLabels(widget.buckets)),
        const SizedBox(height: 10),
        const _Legend(),
        const SizedBox(height: 12),
        _LaneChips(
          lanes: widget.lanes,
          selected: widget.selectedLane,
          onChanged: widget.onLaneChanged,
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 12),
          Divider(color: surfaces.roadLine, height: 1),
          const SizedBox(height: 12),
          for (final line in summary)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line, style: text.bodyMedium),
            ),
        ],
      ],
    );
  }
}

/// The sentence above the chart, naming the minute the bars are reporting.
class _Readout extends StatelessWidget {
  const _Readout({required this.bucket, required this.lane});

  final HistoryBucket? bucket;
  final String? lane;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reading = bucket;
    final scope = lane == null ? 'semua arah' : laneLabel(lane!).toLowerCase();

    if (reading == null) {
      return Text('Belum ada riwayat', style: text.bodyMedium);
    }
    if (!reading.hasData) {
      return Text(
        'Pukul ${hourMinute(reading.minute)} · data tidak masuk',
        style: text.bodyMedium,
      );
    }
    return Text(
      'Pukul ${hourMinute(reading.minute)} · ${reading.count} kendaraan · '
      '${reading.level.label.toLowerCase()} · $scope',
      style: text.bodyMedium,
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({
    required this.buckets,
    required this.touched,
    required this.onTouch,
  });

  final List<HistoryBucket> buckets;
  final int? touched;
  final ValueChanged<int> onTouch;

  @override
  Widget build(BuildContext context) {
    final colors = CongestionColors.of(context);
    final surfaces = FlowSurfaces.of(context);

    if (buckets.isEmpty) {
      return SizedBox(
        height: HistoryChart.chartHeight,
        child: Center(
          child: Text(
            'Belum ada riwayat untuk simpang ini',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    final peak = buckets
        .where((b) => b.hasData)
        .fold<int>(0, (m, b) => b.count! > m ? b.count! : m);

    return Semantics(
      label: 'Grafik 60 menit terakhir',
      child: SizedBox(
        height: HistoryChart.chartHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < buckets.length; i++)
              Expanded(
                child: _Bar(
                  bucket: buckets[i],
                  peak: peak,
                  isTouched: touched == i,
                  colors: colors,
                  surfaces: surfaces,
                  onTap: () => onTouch(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.bucket,
    required this.peak,
    required this.isTouched,
    required this.colors,
    required this.surfaces,
    required this.onTap,
  });

  final HistoryBucket bucket;
  final int peak;
  final bool isTouched;
  final CongestionColors colors;
  final FlowSurfaces surfaces;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final height = bucket.hasData && peak > 0
        ? (bucket.count! / peak * HistoryChart.chartHeight)
            .clamp(2.0, HistoryChart.chartHeight)
        : HistoryChart.gapStubHeight;

    // The touch target is the full height of the chart, not the height of the
    // bar. A one-vehicle minute is three pixels tall; requiring a rider to hit
    // three pixels would make the chart decorative.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: HistoryChart.chartHeight,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.5),
            child: Container(
              height: height.toDouble(),
              decoration: BoxDecoration(
                color: bucket.hasData
                    ? colors.forLevel(bucket.level)
                    : surfaces.faintInk,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
                border: isTouched
                    ? Border.all(color: surfaces.textPrimary, width: 1)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.length < 3) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(labels[0], style: style),
        Text(labels[1], style: style),
        Text(labels[2], style: style),
      ],
    );
  }
}

/// One line, four entries. `Data hilang` is listed alongside the three levels
/// because an outage is a state the chart shows, not an error it hides.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final colors = CongestionColors.of(context);
    final surfaces = FlowSurfaces.of(context);
    final style = Theme.of(context).textTheme.bodySmall;

    Widget entry(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label, style: style),
          ],
        );

    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        entry(colors.lancar, 'Lancar'),
        entry(colors.padat, 'Padat'),
        entry(colors.macet, 'Macet'),
        entry(surfaces.faintInk, 'Data hilang'),
      ],
    );
  }
}

class _LaneChips extends StatelessWidget {
  const _LaneChips({
    required this.lanes,
    required this.selected,
    required this.onChanged,
  });

  final List<String> lanes;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;

    Widget chip(String label, String? value) {
      final isSelected = selected == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: Semantics(
            button: true,
            selected: isSelected,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? surfaces.textPrimary : surfaces.card,
                borderRadius: BorderRadius.circular(FlowRadius.control),
                border: Border.all(color: surfaces.roadLine),
              ),
              child: Text(
                label,
                style: text.bodyMedium?.copyWith(
                  color: isSelected ? surfaces.card : surfaces.textPrimary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Semua arah', null),
          for (final lane in lanes) chip(laneLabel(lane), lane),
        ],
      ),
    );
  }
}
