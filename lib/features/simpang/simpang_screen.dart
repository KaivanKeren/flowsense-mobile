import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/max_width.dart';
import '../../data/models/intersection.dart';
import '../../data/models/traffic_record.dart';
import '../../data/repository/traffic_repository.dart';
import '../../domain/congestion.dart';
import '../../domain/geo.dart';
import '../../state/providers.dart';
import '../../widgets/widgets.dart';
import '../common/feed_view.dart';
import '../common/relative_time.dart';
import '../detail/intersection_sheet.dart';

/// How the list is ordered.
enum SimpangSort {
  terparah('Terparah dulu'),
  terdekat('Terdekat dulu');

  const SimpangSort(this.label);

  final String label;
}

/// The intersection list — a **peer** of the map, not a supplement.
///
/// This is the screen that still works when tiles fail to load, when location
/// is refused, and when the person holding the phone uses a screen reader. A
/// map cannot be read by TalkBack; a list can, and it carries every fact the
/// map does.
class SimpangScreen extends ConsumerStatefulWidget {
  const SimpangScreen({super.key, this.onOpenMap});

  final VoidCallback? onOpenMap;

  @override
  ConsumerState<SimpangScreen> createState() => _SimpangScreenState();
}

class _SimpangScreenState extends ConsumerState<SimpangScreen> {
  SimpangSort _sort = SimpangSort.terparah;

  void _retry() => unawaited(ref.read(repositoryProvider).poll());

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final intersections = ref.watch(intersectionsProvider).valueOrNull;
    final state = ref.watch(snapshotProvider).valueOrNull;
    final config = ref.watch(appConfigProvider);
    final now = ref.watch(clockProvider).now();
    final here = ref.watch(deviceLocationProvider).valueOrNull;

    return Scaffold(
      backgroundColor: colors.surfaceCanvas,
      appBar: AppBar(
        title: const Text('Simpang'),
        titleSpacing: FlowSpace.lg,
        actions: [if (ref.watch(isDemoProvider)) const DemoBadge()],
      ),
      body: MaxWidth448(
        child: Builder(builder: (context) {
          if (intersections == null || state == null || state is RepoLoading) {
            return const SkeletonList(rows: 6);
          }

          final FeedView(:snapshot, :banner) = FeedView.of(state, now);
          if (snapshot == null) {
            return MessageState.error(
              message: 'Tidak ada koneksi. Belum ada data tersimpan.',
              actionLabel: 'Coba lagi',
              onAction: _retry,
            );
          }
          if (snapshot.records.isEmpty) {
            return MessageState.empty(
              message: 'Belum ada data masuk dari simpang mana pun.',
              actionLabel: 'Coba lagi',
              onAction: _retry,
            );
          }

          final rows = [
            for (final intersection in intersections)
              _Row.of(
                intersection,
                snapshot.forCamera(intersection.id),
                now,
                config.staleAfter,
                config.laneCapacityDefault,
                here == null
                    ? null
                    : distanceKm(
                        here.lat,
                        here.lon,
                        intersection.lat,
                        intersection.lon,
                      ),
              ),
          ];
          _sortRows(rows);

          return Column(
            children: [
              if (banner != null)
                StaleNotice(message: banner, onRetry: _retry),
              _SortTabs(
                sort: _sort,
                // With no fix there is nothing to measure from, so the option
                // is hidden rather than shown broken. The list keeps working.
                showNearest: here != null,
                onChanged: (sort) => setState(() => _sort = sort),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: colors.borderSubtle, height: 1),
                  itemBuilder: (context, i) => _IntersectionRow(
                    row: rows[i],
                    now: now,
                    onTap: () => _open(rows[i], now, config.laneCapacityDefault),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Worst first by default. Ties break on volume, then name, so the list holds
  /// still between polls instead of shuffling under a moving thumb.
  void _sortRows(List<_Row> rows) {
    switch (_sort) {
      case SimpangSort.terparah:
        rows.sort((a, b) {
          final byLevel = b.level.severity.compareTo(a.level.severity);
          if (byLevel != 0) return byLevel;
          final byVolume = b.vehicles.compareTo(a.vehicles);
          if (byVolume != 0) return byVolume;
          return a.intersection.name.compareTo(b.intersection.name);
        });
      case SimpangSort.terdekat:
        rows.sort((a, b) {
          final ad = a.distanceKm;
          final bd = b.distanceKm;
          if (ad == null && bd == null) {
            return a.intersection.name.compareTo(b.intersection.name);
          }
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);
        });
    }
  }

  void _open(_Row row, DateTime now, int laneCapacityDefault) {
    ref.read(selectedIntersectionProvider.notifier).state = row.intersection.id;
    unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: IntersectionSheet(
          intersection: row.intersection,
          record: row.record,
          level: row.level,
          isStale: row.isStale,
          now: now,
          laneCapacityDefault: laneCapacityDefault,
          history: ref.watch(historyProvider(row.intersection.id)).valueOrNull ??
              const [],
          onRetry: _retry,
        ),
      ),
    ));
  }
}

/// Top-level for the same reason as on the map: a class with an `isStale`
/// field cannot call the `isStale` rule from its own factory.
bool _stale(TrafficRecord? record, DateTime now, Duration staleAfter) =>
    record == null || isStale(record, now, staleAfter);

class _Row {
  const _Row({
    required this.intersection,
    required this.record,
    required this.level,
    required this.isStale,
    required this.distanceKm,
  });

  factory _Row.of(
    Intersection intersection,
    TrafficRecord? record,
    DateTime now,
    Duration staleAfter,
    int laneCapacityDefault,
    double? distanceKm,
  ) =>
      _Row(
        intersection: intersection,
        record: record,
        level: record == null
            ? CongestionLevel.unknown
            : levelForIntersection(record, intersection,
                laneCapacityDefault: laneCapacityDefault),
        isStale: _stale(record, now, staleAfter),
        distanceKm: distanceKm,
      );

  final Intersection intersection;
  final TrafficRecord? record;
  final CongestionLevel level;
  final bool isStale;
  final double? distanceKm;

  int get vehicles => record?.totalVehicles ?? 0;
}

class _SortTabs extends StatelessWidget {
  const _SortTabs({
    required this.sort,
    required this.showNearest,
    required this.onChanged,
  });

  final SimpangSort sort;
  final bool showNearest;
  final ValueChanged<SimpangSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);

    final options = [
      SimpangSort.terparah,
      if (showNearest) SimpangSort.terdekat,
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: sort == option,
                label: option.label,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(option),
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: FlowTouch.minTarget),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: sort == option
                              ? colors.textPrimary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      option.label,
                      style: type.body.copyWith(
                        color: sort == option
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A bordered row, not a rounded card — this is an index, and cards would make
/// five entries look like five separate things.
class _IntersectionRow extends StatelessWidget {
  const _IntersectionRow({
    required this.row,
    required this.now,
    required this.onTap,
  });

  final _Row row;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);

    final facts = <String>[
      if (row.record != null) '${row.vehicles} kendaraan',
      if (row.distanceKm != null) formatDistance(row.distanceKm!),
      if (row.record != null)
        relativeIndonesian(now.difference(row.record!.ts))
      else
        'belum ada data',
    ];

    return Semantics(
      button: true,
      // Everything the marker conveys, spoken. This is the accessible route
      // through the same data the map shows.
      label: '${row.intersection.name}, '
          '${statusLabel(row.level, isStale: row.isStale).toLowerCase()}, '
          '${facts.join(', ')}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpace.lg,
            vertical: FlowSpace.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.intersection.name, style: type.sectionTitle),
                    const SizedBox(height: FlowSpace.xs),
                    Text(
                      facts.join(' · '),
                      style: type.caption
                          .copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FlowSpace.md),
              // No prefix: the row's own Semantics already says which
              // intersection this is.
              StatusChip.congestion(
                level: row.level,
                isStale: row.isStale,
                semanticsPrefix: null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
