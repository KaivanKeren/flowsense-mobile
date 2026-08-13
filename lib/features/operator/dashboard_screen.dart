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
import '../common/feed_view.dart';
import '../common/relative_time.dart';
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

    return Text(
      'Masuk sebagai ${auth.operator.nama}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: FlowTypography.of(context).caption,
    );
  }
}

class _Body extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);
    final intersections = ref.watch(intersectionsProvider).valueOrNull;
    final state = ref.watch(snapshotProvider).valueOrNull;
    final config = ref.watch(appConfigProvider);
    final now = ref.watch(clockProvider).now();

    void retry() => unawaited(ref.read(repositoryProvider).poll());

    // Loading. A skeleton in the shape of the summary grid and the list, so
    // the page says what is coming and does not jump when it lands.
    if (intersections == null || state == null || state is RepoLoading) {
      return const SkeletonList(rows: 5);
    }

    final FeedView(:snapshot, :banner) = FeedView.of(state, now);

    // Error: nothing cached, nothing reachable.
    if (snapshot == null) {
      return MessageState.error(
        title: 'Tidak ada koneksi',
        message: 'Belum ada data tersimpan di perangkat ini.',
        actionLabel: 'Coba lagi',
        onAction: retry,
      );
    }

    // Empty: reachable, but no intersection has ever reported.
    if (snapshot.records.isEmpty) {
      return MessageState.empty(
        title: 'Belum ada data',
        message: 'Belum ada data masuk dari simpang mana pun.',
        actionLabel: 'Coba lagi',
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

    final newest = snapshot.records
        .map((r) => r.ts)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    return Column(
      children: [
        // Stale: the last good data keeps rendering underneath. A failed poll
        // must never empty the screen; it only ever adds this strip.
        if (banner != null) StaleNotice(message: banner, onRetry: retry),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              FlowSpace.lg,
              FlowSpace.md,
              FlowSpace.lg,
              FlowSpace.xxl,
            ),
            children: [
              _ScreenHeader(age: now.difference(newest), isStale: banner != null),
              const SizedBox(height: FlowSpace.md),
              _SummaryCard(
                summary: summarise([
                  for (final r in rows) (level: r.level, isStale: r.isStale),
                ]),
              ),
              const SizedBox(height: FlowSpace.xl),
              const _AlertsSection(),
              const SizedBox(height: FlowSpace.xl),
              const SectionHeader(
                title: 'Simpang',
                mono: true,
                trailing: Text('urut terparah dulu'),
              ),
              const SizedBox(height: FlowSpace.sm),
              _IntersectionCard(rows: rows, now: now),
              const SizedBox(height: FlowSpace.sm),
              Text(
                'Konsol ini hanya membaca. Tidak ada kendali lampu lalu '
                'lintas.',
                style: type.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Who is looking, and how current what they are looking at is.
class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.age, required this.isStale});

  final Duration age;
  final bool isStale;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: FlowSpace.md,
        runSpacing: FlowSpace.xs,
        children: [
          const _SignedInLine(),
          LiveIndicator(age: age, isStale: isStale),
        ],
      );
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

class _AlertsSection extends ConsumerWidget {
  const _AlertsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);
    final now = ref.watch(clockProvider).now();
    final alerts = ref.watch(operatorAlertsProvider);

    final all = alerts.valueOrNull ?? const <OperatorAlert>[];
    final active = all.where((a) => !a.isAcknowledged).toList();
    final acknowledged = all.where((a) => a.isAcknowledged).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Peringatan aktif', mono: true),
        const SizedBox(height: FlowSpace.sm),
        if (active.isEmpty)
          // A sentence saying it is empty, not an empty section.
          Text(
            'Tidak ada peringatan aktif',
            style: type.body.copyWith(color: colors.textSecondary),
          )
        else
          for (final alert in active)
            Padding(
              padding: const EdgeInsets.only(bottom: FlowSpace.sm),
              child: _AlertCard(alert: alert, now: now),
            ),
        // Acknowledged alerts stay on the page. Their history is the
        // accountability the console exists to provide.
        for (final alert in acknowledged)
          Padding(
            padding: const EdgeInsets.only(top: FlowSpace.sm),
            child: Text(
              '${alert.name} · diakui ${alert.acknowledgedBy} '
              '${clockTime(alert.acknowledgedAt!)}',
              style: type.caption.copyWith(color: colors.textMuted),
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
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);
    final alert = widget.alert;

    final summary = '${alert.level.label} sejak '
        '${clockTime(alert.raisedAt)} · '
        '${durationIndonesian(alert.age(widget.now))}';

    return AppCard(
      padding: const EdgeInsets.all(FlowSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  label: '${alert.name}, $summary',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.name, style: type.sectionTitle),
                      const SizedBox(height: FlowSpace.xs),
                      Text(summary, style: type.metricUnit),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: FlowSpace.md),
              OutlinedButton(
                onPressed: _busy ? null : _acknowledge,
                child: _busy
                    ? SizedBox(
                        width: FlowIconSize.sm,
                        height: FlowIconSize.sm,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.textPrimary,
                        ),
                      )
                    : const Text('Akui'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: FlowSpace.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: type.caption.copyWith(color: colors.statusEmergency),
              ),
            ),
          ],
        ],
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
    final colors = AppColors.of(context);

    return AppCard(
      // Zero, because the rows draw their own padding and the dividers have to
      // run the full width of the card.
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.borderSubtle),
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
/// This is what a wide desktop table becomes on a 360 px phone. The minimum
/// height keeps the touch target above the 48 dp floor even when both lines
/// are short.
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
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);
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
      constraints: const BoxConstraints(minHeight: FlowTouch.minTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: FlowSpace.md,
        vertical: FlowSpace.md,
      ),
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
                        style: type.sectionTitle,
                      ),
                    ),
                    if (status.isStale) ...[
                      const SizedBox(width: FlowSpace.sm),
                      // Shown only when something is wrong, and in the
                      // emergency ink rather than the congestion red — those
                      // four hues mean congestion and nothing else.
                      _HealthDot(color: colors.statusEmergency),
                    ],
                  ],
                ),
                const SizedBox(height: FlowSpace.xs),
                Text(facts, style: type.caption),
              ],
            ),
          ),
          const SizedBox(width: FlowSpace.md),
          // No prefix: the row's own Semantics already says which intersection
          // this is, and repeating it would have a screen reader announce the
          // name twice.
          StatusChip.congestion(
            level: status.level,
            isStale: status.isStale,
            semanticsPrefix: null,
          ),
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
        width: FlowSpace.sm,
        height: FlowSpace.sm,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
