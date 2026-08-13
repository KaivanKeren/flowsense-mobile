import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/app_version.dart';
import '../../core/max_width.dart';
import '../../data/models/intersection.dart';
import '../../data/models/traffic_record.dart';
import '../../domain/congestion.dart';
import '../../domain/history.dart';
import '../../domain/lane_label.dart';
import '../../domain/video_panel_state.dart';
import '../../state/providers.dart';
import '../../widgets/status_chip.dart';
import '../common/feed_view.dart';
import '../common/stale_banner.dart';
import 'kalibrasi_screen.dart';

/// One intersection, in the depth an operator needs.
///
/// Order, from the layout spec: camera, lanes, a day of history, then where
/// the data came from. The camera leads here — unlike the citizen sheet, where
/// it sits last — because an operator checking a suspicious reading wants to
/// look at the road before trusting the numbers about it.
class DetailScreen extends ConsumerWidget {
  const DetailScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = FlowSurfaces.of(context);
    final intersections = ref.watch(intersectionsProvider).valueOrNull;
    final state = ref.watch(snapshotProvider).valueOrNull;
    final config = ref.watch(appConfigProvider);
    final now = ref.watch(clockProvider).now();

    final intersection = intersections
        ?.where((i) => i.id == cameraId)
        .cast<Intersection?>()
        .firstWhere((i) => true, orElse: () => null);

    return Scaffold(
      backgroundColor: surfaces.page,
      // Title only. The `Kalibrasi` button used to sit in `actions`, and an
      // app bar gives its title whatever the actions leave — so at 320 px and
      // textScale 1.3 `Simpang DPRD` was handed 165 of the 169 px it needed
      // and rendered as `Simpang DPR…`. The button moves into the header
      // below, where it has the full column width and a name of any length
      // fits beside it.
      appBar: AppBar(title: Text(intersection?.name ?? 'Simpang')),
      body: MaxWidth448(
        child: Builder(
          key: const ValueKey('detail-body'),
          builder: (context) {
            if (intersections == null || state == null || intersection == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final FeedView(:snapshot, :banner) = FeedView.of(state, now);
            final record = snapshot?.forCamera(cameraId);
            final stale =
                record == null || isStale(record, now, config.staleAfter);
            final level = record == null
                ? CongestionLevel.unknown
                : levelForIntersection(
                    record,
                    intersection,
                    laneCapacityDefault: config.laneCapacityDefault,
                  );

            return Column(
              children: [
                if (banner != null) StaleBanner(message: banner),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      _Header(
                        record: record,
                        level: level,
                        isStale: stale,
                        now: now,
                        cameraId: cameraId,
                      ),
                      const SizedBox(height: FlowSpace.md),
                      const _CameraPanel(),
                      const SizedBox(height: 20),
                      _Section(
                        title: 'Per lajur',
                        child: _Lanes(
                          intersection: intersection,
                          record: record,
                          isStale: stale,
                          laneCapacityDefault: config.laneCapacityDefault,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _Section(
                        title: 'Riwayat 24 jam',
                        child: _DayHistory(
                          intersection: intersection,
                          cameraId: cameraId,
                          now: now,
                          laneCapacityDefault: config.laneCapacityDefault,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _Section(
                        title: 'Sumber data',
                        child: _SourceNotes(
                          cameraId: cameraId,
                          record: record,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.record,
    required this.level,
    required this.isStale,
    required this.now,
    required this.cameraId,
  });

  final TrafficRecord? record;
  final CongestionLevel level;
  final bool isStale;
  final DateTime now;
  final String cameraId;

  @override
  Widget build(BuildContext context) {
    final type = FlowTypography.of(context);
    final reading = record;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FlowSpace.lg,
        FlowSpace.sm,
        FlowSpace.lg,
        0,
      ),
      // Wrap rather than Row: the chip, the reading and the button are three
      // items of unpredictable width, and at textScale 1.3 on a 320 px screen
      // they stop fitting on one line. Wrapping puts the button underneath;
      // a Row would have overflowed or squeezed the reading to nothing.
      child: Wrap(
        spacing: FlowSpace.md,
        runSpacing: FlowSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusChip.congestion(level: level, isStale: isStale),
          Text(
            reading == null
                ? 'Belum ada data untuk simpang ini'
                : '${reading.totalVehicles} kendaraan · '
                    '${relativeIndonesian(now.difference(reading.ts))}',
            style: type.metricUnit,
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => KalibrasiScreen(cameraId: cameraId),
              ),
            ),
            child: const Text('Kalibrasi'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: surfaces.textSecondary),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// The live view, with its three states written on it.
///
/// There is **no stream to play yet**: `docs/api-contract.md` has no camera
/// proxy endpoint, so wiring a player would be guessing at a URL. The panel
/// therefore opens in its failed state, which is the honest one — and the
/// buffering policy that governs a real stream already exists, tested, in
/// [VideoPanelState].
class _CameraPanel extends StatefulWidget {
  const _CameraPanel();

  @override
  State<_CameraPanel> createState() => _CameraPanelState();
}

class _CameraPanelState extends State<_CameraPanel> {
  // No proxy configured, so there is nothing to connect to.
  VideoPanelState _state = const VideoPanelState().failed();

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(
            color: surfaces.textPrimary,
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  left: 10,
                  child: _StreamBadge(phase: _state.phase),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _state.phase == VideoPhase.gagal
                            ? Icons.videocam_off_outlined
                            : Icons.videocam_outlined,
                        size: 32,
                        color: surfaces.faintInk,
                      ),
                      if (_state.phase == VideoPhase.gagal) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => setState(
                            () => _state = _state.manualReload(),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: surfaces.card,
                            side: BorderSide(color: surfaces.faintInk),
                          ),
                          child: const Text('Muat ulang'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Sumber: portal CCTV Pemkab Kudus, diteruskan lewat server',
            style: text.bodySmall?.copyWith(color: surfaces.textFaint),
          ),
        ),
      ],
    );
  }
}

class _StreamBadge extends StatelessWidget {
  const _StreamBadge({required this.phase});

  final VideoPhase phase;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.page,
        borderRadius: BorderRadius.circular(FlowRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          phase.label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: surfaces.textPrimary),
        ),
      ),
    );
  }
}

/// The citizen lane rows plus the two columns an operator needs: the capacity
/// being divided by, and the ratio it produces.
class _Lanes extends StatelessWidget {
  const _Lanes({
    required this.intersection,
    required this.record,
    required this.isStale,
    required this.laneCapacityDefault,
  });

  final Intersection intersection;
  final TrafficRecord? record;
  final bool isStale;
  final int laneCapacityDefault;

  @override
  Widget build(BuildContext context) {
    final reading = record;

    // Absence of data is never a clear road, here least of all — this is the
    // screen an operator opens to decide whether to trust a number.
    if (reading == null || reading.perLane.isEmpty) {
      return Text(
        'Tidak ada rincian lajur.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      children: [
        for (final lane in intersection.orderedLanes(reading.perLane.keys))
          _LaneRow(
            key: ValueKey('lane-$lane'),
            lane: lane,
            count: reading.perLane[lane]!,
            capacity:
                intersection.capacityFor(lane, fallback: laneCapacityDefault),
            isStale: isStale,
          ),
      ],
    );
  }
}

class _LaneRow extends StatelessWidget {
  const _LaneRow({
    super.key,
    required this.lane,
    required this.count,
    required this.capacity,
    required this.isStale,
  });

  final String lane;
  final int count;
  final int capacity;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final colors = CongestionColors.of(context);
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;

    final level = levelForLane(count, capacity);
    final color = colors.forLevel(isStale ? CongestionLevel.unknown : level);
    final ratio = capacity <= 0 ? 0.0 : (count / capacity).clamp(0.0, 1.0);
    final percent = capacity <= 0 ? null : (count / capacity * 100).round();

    return Semantics(
      label: '${laneLabel(lane)}, $count dari $capacity kendaraan, '
          '${percent == null ? 'kapasitas belum dikalibrasi' : '$percent persen'}, '
          '${statusLabel(level, isStale: isStale).toLowerCase()}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              child: Text(
                laneLabel(lane),
                style: text.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(color: surfaces.roadLine),
                      ),
                      // Both `Positioned.fill` and `heightFactor: 1` are load
                      // bearing. Without the factor the child is handed loose
                      // vertical constraints and a `ColoredBox` collapses to
                      // zero height — a bar that is invisible while every
                      // text assertion about it still passes.
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: ratio,
                            heightFactor: 1,
                            child: ColoredBox(color: color),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 38,
              child: Text(
                '$count/$capacity',
                textAlign: TextAlign.right,
                style:
                    text.bodySmall?.copyWith(color: surfaces.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 34,
              child: Text(
                percent == null ? '—' : '$percent%',
                textAlign: TextAlign.right,
                // Neutral ink. The bar already carries the level, and the
                // congestion reds are reserved — and would fail contrast at
                // this size anyway.
                style: text.bodySmall?.copyWith(color: surfaces.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 96 bars, one per quarter hour.
///
/// Height is the vehicle count, colour the worst lane — the same two encodings
/// as the citizen chart, for the same reason. A quarter hour nothing arrived
/// for is drawn flat at the base and **never interpolated across**.
class _DayHistory extends ConsumerStatefulWidget {
  const _DayHistory({
    required this.intersection,
    required this.cameraId,
    required this.now,
    required this.laneCapacityDefault,
  });

  final Intersection intersection;
  final String cameraId;
  final DateTime now;
  final int laneCapacityDefault;

  static const double chartHeight = 96;
  static const double gapStubHeight = 3;

  @override
  ConsumerState<_DayHistory> createState() => _DayHistoryState();
}

class _DayHistoryState extends ConsumerState<_DayHistory> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final colors = CongestionColors.of(context);
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;

    final records =
        ref.watch(operatorHistoryProvider(widget.cameraId)).valueOrNull ??
            const <TrafficRecord>[];

    final buckets = bucketHistory(
      records: records,
      intersection: widget.intersection,
      end: widget.now,
      count: kOperatorHistoryBuckets,
      bucketSize: kOperatorHistoryBucket,
      laneCapacityDefault: widget.laneCapacityDefault,
    );

    final peak = buckets
        .where((b) => b.hasData)
        .fold<int>(0, (m, b) => b.count! > m ? b.count! : m);

    final cursor = _touched == null
        ? null
        : buckets[_touched!.clamp(0, buckets.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cursor == null
              ? 'Ketuk batang untuk melihat periodenya'
              : cursor.hasData
                  ? 'Pukul ${hourMinute(cursor.minute)} · '
                      '${cursor.count} kendaraan · '
                      '${cursor.level.label.toLowerCase()}'
                  : 'Pukul ${hourMinute(cursor.minute)} · data tidak masuk',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          key: const ValueKey('history-bars'),
          height: _DayHistory.chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < buckets.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _touched = i),
                    child: SizedBox(
                      // Full-height target: at 96 bars across 360 px each one
                      // is about 3 px wide, so the vertical run is all the
                      // room a thumb gets.
                      height: _DayHistory.chartHeight,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: buckets[i].hasData && peak > 0
                              ? (buckets[i].count! /
                                      peak *
                                      _DayHistory.chartHeight)
                                  .clamp(2.0, _DayHistory.chartHeight)
                              : _DayHistory.gapStubHeight,
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          color: buckets[i].hasData
                              ? colors.forLevel(buckets[i].level)
                              : surfaces.faintInk,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(hourMinute(buckets.first.minute), style: text.bodySmall),
            Text(
              hourMinute(buckets[buckets.length ~/ 2].minute),
              style: text.bodySmall,
            ),
            Text('sekarang', style: text.bodySmall),
          ],
        ),
      ],
    );
  }
}

/// Where the numbers came from, so a suspicious reading can be chased.
class _SourceNotes extends StatelessWidget {
  const _SourceNotes({required this.cameraId, required this.record});

  final String cameraId;
  final TrafficRecord? record;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;
    final reading = record;

    String seconds(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';

    final lines = <String>[
      // The layout doc asks for the camera URL. There is no URL in the record
      // schema or the API contract, so the id is what can honestly be shown.
      'Kamera $cameraId',
      if (reading != null)
        // Seconds, not "2 menit lalu": someone chasing a stalled feed is
        // comparing this against the connector's own log.
        'Record terakhir ${seconds(reading.ts)}'
      else
        'Belum ada record',
      'Connector v$kAppVersion',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: text.bodySmall?.copyWith(color: surfaces.textSecondary),
            ),
          ),
      ],
    );
  }
}
