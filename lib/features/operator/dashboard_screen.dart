import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/max_width.dart';
import '../../data/models/intersection.dart';
import '../../data/models/traffic_record.dart';
import '../../data/models/traffic_snapshot.dart';
import '../../data/repository/traffic_repository.dart';
import '../../domain/congestion.dart';
import '../../state/providers.dart';
import '../common/feed_view.dart';
import '../common/stale_banner.dart';
import 'history_chart.dart';
import 'lane_bars.dart';

/// One intersection as the operator list sees it.
class IntersectionStatus {
  const IntersectionStatus({
    required this.intersection,
    required this.record,
    required this.level,
    required this.isStale,
  });

  final Intersection intersection;
  final TrafficRecord? record;
  final CongestionLevel level;
  final bool isStale;

  int get totalVehicles => record?.totalVehicles ?? 0;
}

/// Worst first — the whole point of the dashboard is that the intersection
/// needing attention is at the top without anyone scrolling for it.
///
/// A camera with no usable data sorts **last**, not first: a dead feed is not
/// an emergency, and letting `unknown` head the list would bury a real jam.
/// Ties break on volume then name, so the list does not reshuffle between polls
/// when two intersections share a level.
List<IntersectionStatus> rankWorstFirst({
  required List<Intersection> intersections,
  required TrafficSnapshot snapshot,
  required DateTime now,
  required Duration staleAfter,
  int laneCapacityDefault = 12,
}) {
  final rows = [
    for (final intersection in intersections)
      () {
        final record = snapshot.forCamera(intersection.id);
        return IntersectionStatus(
          intersection: intersection,
          record: record,
          level: record == null
              ? CongestionLevel.unknown
              : levelForIntersection(
                  record,
                  intersection,
                  laneCapacityDefault: laneCapacityDefault,
                ),
          isStale: record == null || isStale(record, now, staleAfter),
        );
      }(),
  ];

  rows.sort((a, b) {
    final bySeverity = b.level.severity.compareTo(a.level.severity);
    if (bySeverity != 0) return bySeverity;
    final byVolume = b.totalVehicles.compareTo(a.totalVehicles);
    if (byVolume != 0) return byVolume;
    return a.intersection.name.compareTo(b.intersection.name);
  });
  return rows;
}

/// The operator view: every intersection ranked worst-first, each with its
/// per-lane split, and an hour of history for whichever one is open.
///
/// Read-only, deliberately. Signal control from a phone is a safety question,
/// not a feature question.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: const Text('Papan operator'),
          actions: [if (ref.watch(isDemoProvider)) const DemoBadge()],
        ),
        body: MaxWidth448(child: _content(context, ref)),
      );

  Widget _content(BuildContext context, WidgetRef ref) {
    final intersections = ref.watch(intersectionsProvider).valueOrNull;
    final state = ref.watch(snapshotProvider).valueOrNull;
    final config = ref.watch(appConfigProvider);
    final now = ref.watch(clockProvider).now();

    void retry() => unawaited(ref.read(repositoryProvider).poll());

    if (intersections == null || state == null || state is RepoLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final FeedView(:snapshot, :banner) = FeedView.of(state, now);

    if (snapshot == null) {
      return QuietState(
        title: 'Data tidak dapat dimuat',
        body: banner ?? 'Coba lagi sebentar.',
        actionLabel: 'Coba lagi',
        onAction: retry,
      );
    }

    if (snapshot.isEmpty) {
      return QuietState(
        title: 'Belum ada data lalu lintas',
        body: 'Pastikan konektor kamera sedang berjalan, lalu muat ulang.',
        actionLabel: 'Muat ulang',
        onAction: retry,
      );
    }

    final rows = rankWorstFirst(
      intersections: intersections,
      snapshot: snapshot,
      now: now,
      staleAfter: config.staleAfter,
      laneCapacityDefault: config.laneCapacityDefault,
    );
    final selected = ref.watch(selectedIntersectionProvider);

    return Column(
      children: [
        if (banner != null) StaleBanner(message: banner, onRetry: retry),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final status = rows[index];
              final id = status.intersection.id;
              return IntersectionCard(
                status: status,
                now: now,
                laneCapacityDefault: config.laneCapacityDefault,
                isExpanded: selected == id,
                // Tapping the open card closes it, so the list can be read
                // without a chart pushing everything else off screen.
                onTap: () => ref
                    .read(selectedIntersectionProvider.notifier)
                    .state = selected == id ? null : id,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One row of the dashboard. Public so a widget test can read the rendered
/// order straight off the tree instead of inferring it from text positions.
class IntersectionCard extends StatelessWidget {
  const IntersectionCard({
    super.key,
    required this.status,
    required this.now,
    required this.isExpanded,
    required this.onTap,
    this.laneCapacityDefault = 12,
  });

  final IntersectionStatus status;
  final DateTime now;
  final bool isExpanded;
  final VoidCallback onTap;
  final int laneCapacityDefault;

  @override
  Widget build(BuildContext context) {
    final colors = CongestionColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color =
        status.isStale ? colors.unknown : colors.forLevel(status.level);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status.intersection.name,
                      style: text.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${status.totalVehicles} kendaraan',
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  switch (status.record) {
                    null => '${status.level.label} · belum ada data',
                    final record => '${status.level.label} · '
                        '${relativeIndonesian(now.difference(record.ts))}',
                  },
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 12),
              LaneBars(
                intersection: status.intersection,
                record: status.record,
                isStale: status.isStale,
                laneCapacityDefault: laneCapacityDefault,
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                Text(
                  'Kendaraan per menit, satu jam terakhir',
                  style: text.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                _HistorySection(cameraId: status.intersection.id, now: now),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Fetches history only for the card the operator actually opened — polling an
/// hour of points for every intersection on every rebuild would be wasteful.
class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.cameraId, required this.now});

  final String cameraId;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(historyProvider(cameraId)).when(
            // Same window the provider asked for, so the axis cannot drift
            // away from the data it is drawing.
            data: (records) => HistoryChart(
              records: records,
              now: now,
              window: kHistoryWindow,
            ),
            loading: () => const SizedBox(
              height: HistoryChart.height,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => SizedBox(
              height: HistoryChart.height,
              child: Center(
                child: Text(
                  'Riwayat tidak dapat dimuat.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          );
}
