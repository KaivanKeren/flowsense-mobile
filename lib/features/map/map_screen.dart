import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/max_width.dart';
import '../../data/models/intersection.dart';
import '../../data/models/traffic_record.dart';
import '../../data/models/traffic_snapshot.dart';
import '../../data/repository/traffic_repository.dart';
import '../../domain/congestion.dart';
import '../../state/providers.dart';
import '../../widgets/widgets.dart';
import '../common/feed_view.dart';
import '../detail/intersection_sheet.dart';
import 'intersection_marker.dart';

/// The citizen-facing screen: every monitored intersection on one map, each
/// coloured by its worst approach.
///
/// The map is the **canvas**, not one panel among several — the search field
/// and the detail sheet float over it rather than sharing the vertical space.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.tileProvider});

  /// Injected in tests so no widget test reaches for an OSM tile.
  final TileProvider? tileProvider;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  String _query = '';

  static const _snapSizes = [0.28, 0.55, 0.92];

  void _retry() => unawaited(ref.read(repositoryProvider).poll());

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final intersections = ref.watch(intersectionsProvider).valueOrNull;
    final state = ref.watch(snapshotProvider).valueOrNull;
    final config = ref.watch(appConfigProvider);
    final now = ref.watch(clockProvider).now();
    final selectedId = ref.watch(selectedIntersectionProvider);

    return Scaffold(
      backgroundColor: colors.surfaceElevated,
      body: MaxWidth448(
        child: SafeArea(
          bottom: false,
          child: _body(context, intersections, state, config, now, selectedId),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<Intersection>? intersections,
    RepoState? state,
    AppConfig config,
    DateTime now,
    String? selectedId,
  ) {
    if (intersections == null || state == null || state is RepoLoading) {
      return const _FirstLoad();
    }

    // A failed poll still renders its last good snapshot — under a banner
    // saying what happened — rather than blanking the screen.
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

    final staleAfter = config.staleAfter;
    final laneCapacityDefault = config.laneCapacityDefault;

    final readings = [
      for (final intersection in intersections)
        _Reading.of(
          intersection,
          snapshot,
          now,
          staleAfter,
          laneCapacityDefault,
        ),
    ];

    final visible = _query.trim().isEmpty
        ? readings
        : readings
            .where((r) => r.intersection.name
                .toLowerCase()
                .contains(_query.trim().toLowerCase()))
            .toList();

    final selected = _selected(readings, selectedId);

    return Stack(
      children: [
        Positioned.fill(
          child: _MapView(
            readings: visible,
            selectedId: selected?.intersection.id,
            tileProvider: widget.tileProvider,
            onSelect: (reading) => ref
                .read(selectedIntersectionProvider.notifier)
                .state = reading.intersection.id,
          ),
        ),
        Positioned(
          top: FlowSpace.sm,
          left: FlowSpace.md,
          right: FlowSpace.md,
          child: _SearchField(
            onChanged: (value) => setState(() => _query = value),
            onSubmitted: (_) {
              if (visible.length == 1) {
                ref.read(selectedIntersectionProvider.notifier).state =
                    visible.single.intersection.id;
              }
            },
          ),
        ),
        // The map has no app bar to hang these on — it is a full canvas — so
        // both notices stack under the search field instead. Neither is
        // optional: one says the feed is behind, the other says the numbers
        // are canned, and a demo that hid either would be passing fixtures
        // off as live traffic.
        Positioned(
          // Measured, not chosen: the search field's `top: FlowSpace.sm` plus
          // its rendered height plus a small gap. This is a map overlay
          // coordinate, not a spacing decision.
          top: 62,
          left: FlowSpace.md,
          right: FlowSpace.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (ref.watch(isDemoProvider)) const DemoBadge(),
              if (banner != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(FlowRadius.md),
                  child: StaleNotice(message: banner, onRetry: _retry),
                ),
            ],
          ),
        ),
        if (selected != null)
          DraggableScrollableSheet(
            key: ValueKey('sheet-${selected.intersection.id}'),
            initialChildSize: _snapSizes.first,
            minChildSize: _snapSizes.first,
            maxChildSize: _snapSizes.last,
            snap: true,
            snapSizes: _snapSizes,
            builder: (context, controller) => _SheetSurface(
              child: IntersectionSheet(
                intersection: selected.intersection,
                record: selected.record,
                level: selected.level,
                isStale: selected.isStale,
                now: now,
                laneCapacityDefault: laneCapacityDefault,
                history: ref
                        .watch(historyProvider(selected.intersection.id))
                        .valueOrNull ??
                    const [],
                nearby: [
                  for (final reading in readings)
                    if (reading.intersection.id != selected.intersection.id)
                      NearbyIntersection(
                        intersection: reading.intersection,
                        level: reading.level,
                        isStale: reading.isStale,
                      ),
                ],
                scrollController: controller,
                onRetry: _retry,
                onSelectNearby: (intersection) => ref
                    .read(selectedIntersectionProvider.notifier)
                    .state = intersection.id,
              ),
            ),
          ),
      ],
    );
  }

  _Reading? _selected(List<_Reading> readings, String? id) {
    if (id == null) return null;
    for (final reading in readings) {
      if (reading.intersection.id == id) return reading;
    }
    return null;
  }
}

/// Top-level, not a static on [_Reading]: a class that carries an `isStale`
/// field cannot call the `isStale` *rule* from inside its own factory — the
/// field wins the name and the analyzer rejects it.
bool _stale(TrafficRecord? record, DateTime now, Duration staleAfter) =>
    record == null || isStale(record, now, staleAfter);

/// One intersection plus whatever the current snapshot says about it.
class _Reading {
  const _Reading({
    required this.intersection,
    required this.record,
    required this.level,
    required this.isStale,
  });

  factory _Reading.of(
    Intersection intersection,
    TrafficSnapshot snapshot,
    DateTime now,
    Duration staleAfter,
    int laneCapacityDefault,
  ) {
    final record = snapshot.forCamera(intersection.id);
    return _Reading(
      intersection: intersection,
      record: record,
      // A camera with no record is unknown, never lancar: absence of data is
      // not a clear road.
      level: record == null
          ? CongestionLevel.unknown
          : levelForIntersection(record, intersection,
              laneCapacityDefault: laneCapacityDefault),
      isStale: _stale(record, now, staleAfter),
    );
  }

  final Intersection intersection;
  final TrafficRecord? record;
  final CongestionLevel level;
  final bool isStale;
}

/// The one place a spinner is honest: before anything at all has arrived.
/// It carries a line of text, so it still says what is happening.
class _FirstLoad extends StatelessWidget {
  const _FirstLoad();

  @override
  Widget build(BuildContext context) {
    final type = FlowTypography.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: FlowIconSize.md,
            height: FlowIconSize.md,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: FlowSpace.md),
          Text('Memuat data simpang', style: type.body),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged, required this.onSubmitted});

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);
    return Material(
      color: colors.surfaceCard,
      elevation: 0,
      borderRadius: BorderRadius.circular(FlowRadius.md),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FlowRadius.md),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: TextField(
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: type.body,
          decoration: InputDecoration(
            hintText: 'Cari simpang',
            hintStyle: type.body.copyWith(color: colors.textSecondary),
            prefixIcon: Icon(
              Icons.search,
              size: FlowIconSize.md,
              color: colors.textSecondary,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: FlowSpace.md,
              vertical: FlowSpace.lg,
            ),
            isDense: true,
          ),
        ),
      ),
    );
  }
}

/// Flat, radius 16 on the top corners only, hairline top edge instead of a
/// shadow.
class _SheetSurface extends StatelessWidget {
  const _SheetSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(FlowRadius.lg),
        ),
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(FlowRadius.lg),
        ),
        child: child,
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({
    required this.readings,
    required this.selectedId,
    required this.onSelect,
    this.tileProvider,
  });

  final List<_Reading> readings;
  final String? selectedId;
  final void Function(_Reading) onSelect;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    // Marker size is relative to the busiest intersection currently displayed,
    // so the map re-ranks itself as traffic moves rather than against a fixed
    // ceiling nobody can see.
    final busiest = readings.fold<int>(
      0,
      (m, r) => (r.record?.totalVehicles ?? 0) > m
          ? r.record!.totalVehicles
          : m,
    );

    return FlutterMap(
      options: MapOptions(
        initialCenter: _center(),
        initialZoom: 13,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'id.ac.umk.flowsense.flowsense_mobile',
          tileProvider: tileProvider,
        ),
        MarkerLayer(
          markers: [
            for (final reading in readings) _marker(reading, busiest),
          ],
        ),
        // OSM tiles carry an attribution obligation. This is a licence
        // requirement, not a nicety.
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Marker _marker(_Reading reading, int busiest) {
    final diameter = IntersectionMarker.diameterFor(
      reading.record?.totalVehicles ?? 0,
      busiest: busiest,
    );

    return Marker(
      key: ValueKey('marker-${reading.intersection.id}'),
      point: LatLng(reading.intersection.lat, reading.intersection.lon),
      width: diameter,
      height: diameter,
      child: IntersectionMarker(
        intersection: reading.intersection,
        record: reading.record,
        level: reading.level,
        isStale: reading.isStale,
        busiestVehicles: busiest,
        isSelected: selectedId == reading.intersection.id,
        isDimmed: selectedId != null && selectedId != reading.intersection.id,
        onTap: () => onSelect(reading),
      ),
    );
  }

  LatLng _center() {
    if (readings.isEmpty) return const LatLng(-6.8047, 110.8405); // Kudus
    final lat = readings.map((r) => r.intersection.lat).reduce((a, b) => a + b) /
        readings.length;
    final lon = readings.map((r) => r.intersection.lon).reduce((a, b) => a + b) /
        readings.length;
    return LatLng(lat, lon);
  }
}
