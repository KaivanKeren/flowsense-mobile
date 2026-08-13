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
import '../../domain/lane_label.dart';
import '../../domain/operator_alert.dart';
import '../../domain/status_summary.dart';
import '../../state/alert_providers.dart';
import '../../state/auth_providers.dart';
import '../../state/providers.dart';
import '../../widgets/widgets.dart';
import '../common/failure_state.dart';
import '../common/feed_view.dart';
import '../common/stale_banner.dart';
import '../common/status_pill.dart';
import 'detail_screen.dart';

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

  /// The approach carrying the intersection's level, or null when there is no
  /// lane data to name one.
  String? get worstLane {
    final perLane = record?.perLane;
    if (perLane == null || perLane.isEmpty) return null;

    String? worst;
    var worstRatio = -1.0;
    for (final lane in intersection.orderedLanes(perLane.keys)) {
      final capacity = intersection.capacityFor(lane, fallback: 12);
      if (capacity <= 0) continue;
      final ratio = perLane[lane]! / capacity;
      if (ratio > worstRatio) {
        worstRatio = ratio;
        worst = lane;
      }
    }
    return worst;
  }
}

/// Worst first — the whole point of the dashboard is that the intersection
/// needing attention is at the top without anyone scrolling for it.
///
/// This is the compensation for losing the wide table a desktop console would
/// have: on a phone you cannot see everything at once, so ordering has to put
/// what matters on the first screen.
///
/// A camera with no usable data sorts **last**, not first: a dead feed is not
/// an emergency, and letting `unknown` head the list would bury a real jam.
/// Ties break on volume then name, so the list does not reshuffle between
/// polls when two intersections share a level.
List<IntersectionStatus> rankWorstFirst({
  required List<Intersection> intersections,
  required TrafficSnapshot snapshot,
  required DateTime now,
  required Duration staleAfter,
  int laneCapacityDefault = 12,
}) {
  final rows = [
    for (final intersection in intersections)
      _statusFor(
        intersection,
        snapshot,
        now,
        staleAfter,
        laneCapacityDefault,
      ),
  ];

  rows.sort((a, b) {
    final byLevel = _rank(b).compareTo(_rank(a));
    if (byLevel != 0) return byLevel;
    final byVolume = b.totalVehicles.compareTo(a.totalVehicles);
    if (byVolume != 0) return byVolume;
    return a.intersection.name.compareTo(b.intersection.name);
  });
  return rows;
}

/// A stale row ranks below every live one, whatever level it last reported.
int _rank(IntersectionStatus s) => s.isStale ? -1 : s.level.severity;

IntersectionStatus _statusFor(
  Intersection intersection,
  TrafficSnapshot snapshot,
  DateTime now,
  Duration staleAfter,
  int laneCapacityDefault,
) {
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
}

/// The operator console's home.
///
/// Order is the argument, and it is the reverse of what a desktop dashboard
/// would do: the summary, then **active alerts**, then the intersection list.
/// On a phone what needs action has to be visible before what needs watching,
/// so alerts sit above the list rather than beside it.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceCanvas,
      appBar: AppBar(
        // The layout doc names the route but not the title; the reference
        // image labels it `Dashboard`, so the image stands.
        title: const Text('Dashboard'),
        titleSpacing: FlowSpace.lg,
        actions: [
          // Says the numbers are bundled fixtures rather than live traffic.
          // Never dropped to make room for chrome: degrading to fixtures keeps
          // a demo alive, doing it silently passes canned data off as real.
          if (ref.watch(isDemoProvider)) const DemoBadge(),
        ],
      ),
      body: MaxWidth448(child: _Body()),
    );
  }
}

/// Who is signed in, and how current the numbers are.
///
/// This used to live in the app bar's `actions`, beside the demo badge, and
/// that is where it broke the screen: at 320 px the title `Dashboard` was left
/// 57 of the 96 px it needed and rendered as `Dashboa…`; at textScale 1.3 it
/// got **15** of 124. An app bar gives its title whatever the actions do not
/// take, so anything of variable width put there is a title truncated by
/// however long somebody's name happens to be.
///
/// Down here the line has the full column width, the name no longer competes
/// with the screen's own identity, and accountability is better served anyway
/// — it reads as a sentence rather than as chrome.
class _SignedInLine extends ConsumerWidget {
  const _SignedInLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth is! AuthSignedIn) return const SizedBox.shrink();

    final type = FlowTypography.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            'Masuk sebagai ${auth.operator.nama}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: type.caption,
          ),
        ),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = FlowSurfaces.of(context);
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
      return FailureState.noConnection(
        lastDataText: 'Belum ada data tersimpan',
        onRetry: retry,
      );
    }
    if (snapshot.records.isEmpty) {
      return FailureState.noData(onRetry: retry);
    }

    final rows = rankWorstFirst(
      intersections: intersections,
      snapshot: snapshot,
      now: now,
      staleAfter: config.staleAfter,
      laneCapacityDefault: config.laneCapacityDefault,
    );

    return Column(
      children: [
        if (banner != null) StaleBanner(message: banner, onRetry: retry),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              FlowSpace.lg,
              FlowSpace.md,
              FlowSpace.lg,
              FlowSpace.xxl,
            ),
            children: [
              const _SignedInLine(),
              const SizedBox(height: FlowSpace.md),
              _SummaryCard(
                summary: summarise([
                  for (final r in rows) (level: r.level, isStale: r.isStale),
                ]),
              ),
              const SizedBox(height: 24),
              const _AlertsSection(),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Simpang',
                trailing: 'urut terparah dulu',
              ),
              const SizedBox(height: 8),
              _IntersectionCard(rows: rows, now: now),
              const SizedBox(height: 8),
              Text(
                'Konsol ini hanya membaca. Tidak ada kendali lampu lalu '
                'lintas.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: surfaces.textFaint),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Four numbers: macet, padat, lancar, tanpa data.
///
/// A wrapping two-column grid, not one row of four. Four cells across a 320 px
/// screen leave 72 px each, and at textScale 1.3 that is a figure and a label
/// fighting over the same space — which is the row the brief describes as cut
/// off at the right edge. Two columns give each number room, and a fifth
/// metric would move down rather than off the screen.
///
/// The numbers are neutral ink, never the level colour. Colour on this screen
/// belongs to the status chips alone — the console is denser than the citizen
/// app, which makes that rule easier to break and more important to hold.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final StatusSummary summary;

  @override
  Widget build(BuildContext context) {
    final cells = <(String, int)>[
      ('Macet', summary.macet),
      ('Padat', summary.padat),
      ('Lancar', summary.lancar),
      ('Tanpa data', summary.tanpaData),
    ];

    return MetricGrid(
      children: [
        for (final (label, value) in cells)
          MetricCard(
            key: ValueKey('summary-$label'),
            label: label,
            value: '$value',
            unit: 'simpang',
            semanticsValue: '$label, $value simpang',
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: text.bodyMedium?.copyWith(color: surfaces.textSecondary),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: text.bodySmall?.copyWith(color: surfaces.textFaint),
          ),
      ],
    );
  }
}

class _AlertsSection extends ConsumerWidget {
  const _AlertsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider).now();
    final alerts = ref.watch(operatorAlertsProvider);

    final all = alerts.valueOrNull ?? const <OperatorAlert>[];
    final active = all.where((a) => !a.isAcknowledged).toList();
    final acknowledged = all.where((a) => a.isAcknowledged).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'Peringatan aktif'),
        const SizedBox(height: 8),
        if (active.isEmpty)
          // A sentence saying it is empty, not an empty section.
          Text(
            'Tidak ada peringatan aktif',
            style: text.bodyMedium?.copyWith(color: surfaces.textSecondary),
          )
        else
          for (final alert in active)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AlertCard(alert: alert, now: now),
            ),
        // Acknowledged alerts stay on the page. Their history is the
        // accountability the console exists to provide.
        for (final alert in acknowledged)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${alert.name} · diakui ${alert.acknowledgedBy} '
              '${clockTime(alert.acknowledgedAt!)}',
              style: text.bodySmall?.copyWith(color: surfaces.textFaint),
            ),
          ),
      ],
    );
  }
}

class _AlertCard extends ConsumerStatefulWidget {
  const _AlertCard({required this.alert, required this.now});

  final OperatorAlert alert;
  final DateTime now;

  @override
  ConsumerState<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends ConsumerState<_AlertCard> {
  bool _busy = false;
  String? _error;

  Future<void> _acknowledge() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final failure = await ref
        .read(operatorAlertsProvider.notifier)
        .acknowledge(widget.alert.id);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;
    final alert = widget.alert;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.card,
        borderRadius: BorderRadius.circular(FlowRadius.card),
        border: Border.all(color: surfaces.roadLine),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.name, style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${alert.level.label} sejak '
                        '${clockTime(alert.raisedAt)} · '
                        '${durationIndonesian(alert.age(widget.now))}',
                        style: text.bodyMedium
                            ?.copyWith(color: surfaces.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _busy ? null : _acknowledge,
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Akui'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: text.bodySmall?.copyWith(color: surfaces.errorInk),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IntersectionCard extends StatelessWidget {
  const _IntersectionCard({required this.rows, required this.now});

  final List<IntersectionStatus> rows;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.card,
        borderRadius: BorderRadius.circular(FlowRadius.card),
        border: Border.all(color: surfaces.roadLine),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: surfaces.roadLine),
            _IntersectionRow(
              status: rows[i],
              now: now,
              onTap: () => unawaited(Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      DetailScreen(cameraId: rows[i].intersection.id),
                ),
              )),
            ),
          ],
        ],
      ),
    );
  }
}

/// Two tiers: identity on the first line, the supporting numbers on the second
/// as secondary text separated by middots.
///
/// This is what a wide desktop table becomes on a 360 px phone. Minimum height
/// 56 so the touch target still clears 44 even when both lines are short.
class _IntersectionRow extends StatelessWidget {
  const _IntersectionRow({
    required this.status,
    required this.now,
    this.onTap,
  });

  final IntersectionStatus status;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;
    final record = status.record;

    final facts = status.isStale
        ? (record == null
            ? 'Belum ada data'
            : 'Data terakhir ${relativeIndonesian(now.difference(record.ts))}')
        : [
            '${status.totalVehicles} kendaraan',
            if (status.worstLane != null)
              laneLabel(status.worstLane!).toLowerCase(),
            relativeIndonesian(now.difference(record!.ts)),
          ].join(' · ');

    final row = Container(
      key: ValueKey('row-${status.intersection.id}'),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        status.intersection.name,
                        style: text.titleMedium,
                      ),
                    ),
                    if (status.isStale) ...[
                      const SizedBox(width: 8),
                      // Shown only when something is wrong, and in the error
                      // ink rather than the congestion red — those four hues
                      // mean congestion and nothing else.
                      _HealthDot(color: surfaces.errorInk),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  facts,
                  style:
                      text.bodySmall?.copyWith(color: surfaces.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StatusPill(level: status.level, isStale: status.isStale),
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label: '${status.intersection.name}, '
          '${statusLabel(status.level, isStale: status.isStale).toLowerCase()}, '
          '$facts',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: status.isStale
            // Dimmed, because a row you cannot trust should not compete with
            // the rows you can.
            ? Opacity(opacity: 0.6, child: row)
            : row,
      ),
    );
  }
}

class _HealthDot extends StatelessWidget {
  const _HealthDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
