import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/max_width.dart';
import '../../data/models/intersection.dart';
import '../../data/models/traffic_record.dart';
import '../../data/models/traffic_snapshot.dart';
import '../../data/repository/traffic_repository.dart';
import '../../domain/congestion.dart';
import '../../state/providers.dart';
import '../common/stale_banner.dart';
import '../detail/intersection_sheet.dart';
import 'intersection_marker.dart';

/// The citizen-facing screen: every monitored intersection on one map, each
/// coloured by its worst approach.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key, this.tileProvider});

  /// Injected in tests so no widget test reaches for an OSM tile.
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Lalu lintas')),
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

    // A failed poll still renders its last good snapshot — under a banner
    // saying what happened — rather than blanking the screen.
    final (TrafficSnapshot? snapshot, String? banner) = switch (state) {
      RepoLoading() => (null, null),
      RepoData(:final snapshot, :final isStale, :final isFromCache) => (
          snapshot,
          isFromCache
              ? 'Data tersimpan. ${_lastDataText(snapshot, now)}'
              : isStale
                  ? _lastDataText(snapshot, now)
                  : null,
        ),
      RepoError(:final message, :final lastGood) => (lastGood, message),
    };

    if (snapshot == null) {
      return _EmptyOrError(
        title: 'Data tidak dapat dimuat',
        body: banner ?? 'Coba lagi sebentar.',
        actionLabel: 'Coba lagi',
        onAction: retry,
      );
    }

    if (snapshot.isEmpty) {
      return _EmptyOrError(
        title: 'Belum ada data lalu lintas',
        body: 'Pastikan konektor kamera sedang berjalan, lalu muat ulang.',
        actionLabel: 'Muat ulang',
        onAction: retry,
      );
    }

    return Column(
      children: [
        if (banner != null) StaleBanner(message: banner, onRetry: retry),
        Expanded(
          child: _MapView(
            intersections: intersections,
            snapshot: snapshot,
            now: now,
            staleAfter: config.staleAfter,
            laneCapacityDefault: config.laneCapacityDefault,
            tileProvider: tileProvider,
            onSelect: (intersection, record, level, stale) {
              ref.read(selectedIntersectionProvider.notifier).state =
                  intersection.id;
              unawaited(showModalBottomSheet<void>(
                context: context,
                showDragHandle: false,
                builder: (_) => IntersectionSheet(
                  intersection: intersection,
                  record: record,
                  level: level,
                  isStale: stale,
                  now: now,
                  laneCapacityDefault: config.laneCapacityDefault,
                ),
              ));
            },
          ),
        ),
      ],
    );
  }

  static String _lastDataText(TrafficSnapshot snapshot, DateTime now) {
    final newest = snapshot.records.isEmpty
        ? snapshot.fetchedAt
        : snapshot.records
            .map((r) => r.ts)
            .reduce((a, b) => a.isAfter(b) ? a : b);
    return 'Data terakhir ${relativeIndonesian(now.difference(newest))}';
  }
}

typedef OnSelectIntersection = void Function(
  Intersection intersection,
  TrafficRecord? record,
  CongestionLevel level,
  bool isStale,
);

class _MapView extends StatelessWidget {
  const _MapView({
    required this.intersections,
    required this.snapshot,
    required this.now,
    required this.staleAfter,
    required this.laneCapacityDefault,
    required this.onSelect,
    this.tileProvider,
  });

  final List<Intersection> intersections;
  final TrafficSnapshot snapshot;
  final DateTime now;
  final Duration staleAfter;
  final int laneCapacityDefault;
  final OnSelectIntersection onSelect;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) => FlutterMap(
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
          MarkerLayer(markers: [for (final i in intersections) _marker(i)]),
          // OSM tiles carry an attribution obligation. This is a licence
          // requirement, not a nicety.
          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('OpenStreetMap contributors'),
            ],
          ),
        ],
      );

  Marker _marker(Intersection intersection) {
    final record = snapshot.forCamera(intersection.id);
    final stale = record == null || isStale(record, now, staleAfter);
    final level = record == null
        ? CongestionLevel.unknown
        : levelForIntersection(record, intersection,
            laneCapacityDefault: laneCapacityDefault);
    final diameter =
        IntersectionMarker.diameterFor(record?.totalVehicles ?? 0);

    return Marker(
      key: ValueKey('marker-${intersection.id}'),
      point: LatLng(intersection.lat, intersection.lon),
      width: diameter,
      height: diameter,
      child: IntersectionMarker(
        intersection: intersection,
        record: record,
        level: level,
        isStale: stale,
        laneCapacityDefault: laneCapacityDefault,
        onTap: () => onSelect(intersection, record, level, stale),
      ),
    );
  }

  LatLng _center() {
    if (intersections.isEmpty) return const LatLng(-6.8047, 110.8405); // Kudus
    final lat = intersections.map((i) => i.lat).reduce((a, b) => a + b) /
        intersections.length;
    final lon = intersections.map((i) => i.lon).reduce((a, b) => a + b) /
        intersections.length;
    return LatLng(lat, lon);
  }
}

/// Both quiet states share a shape: what is going on, and what to do about it.
class _EmptyOrError extends StatelessWidget {
  const _EmptyOrError({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              body,
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
