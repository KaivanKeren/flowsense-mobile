import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/max_width.dart';
import '../../domain/alert_filter.dart';
import '../../domain/congestion.dart';
import '../../domain/operator_alert.dart';
import '../../state/alert_providers.dart';
import '../../state/providers.dart';
import '../common/failure_state.dart';

/// The alert record.
///
/// Cards rather than a table — a table needs columns, and on 360 px columns
/// become horizontal scrolling, which the layout spec forbids. There is no
/// export: it is out of scope, and a disabled export button would be a
/// promise the console cannot keep.
class PeringatanScreen extends ConsumerStatefulWidget {
  const PeringatanScreen({super.key});

  @override
  ConsumerState<PeringatanScreen> createState() => _PeringatanScreenState();
}

class _PeringatanScreenState extends ConsumerState<PeringatanScreen> {
  AlertFilter _filter = const AlertFilter();

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final now = ref.watch(clockProvider).now();
    final alerts = ref.watch(operatorAlertsProvider);
    final intersections = ref.watch(intersectionsProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: surfaces.page,
      appBar: AppBar(title: const Text('Peringatan')),
      body: MaxWidth448(
        child: Column(
          key: const ValueKey('peringatan-body'),
          children: [
            _Filters(
              filter: _filter,
              intersections: {
                for (final i in intersections) i.id: i.name,
              },
              onChanged: (next) => setState(() => _filter = next),
            ),
            Expanded(
              child: switch (alerts) {
                AsyncLoading() =>
                  const Center(child: CircularProgressIndicator()),
                AsyncError() => FailureState(
                    message: 'Riwayat peringatan tidak dapat dimuat.',
                    actionLabel: 'Coba lagi',
                    onAction: () => ref.invalidate(operatorAlertsProvider),
                  ),
                AsyncData(:final value) => _AlertList(
                    alerts: applyAlertFilter(value, _filter, now),
                    now: now,
                  ),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.alerts, required this.now});

  final List<OperatorAlert> alerts;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const FailureState.noAlerts();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: alerts.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _AlertCard(alert: alerts[i], now: now),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.now});

  final OperatorAlert alert;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;
    final summary = alertSummaryLine(alert, now);
    final accent = _accentColor(context, alert.level);

    // A tier-coloured left rail signals severity without borrowing the full
    // congestion palette (spec §27) — the rail is 3 px, the rest of the
    // border stays the hairline so the row still reads as a card first and a
    // severity marker second. An acknowledged alert loses the rail: the
    // accent belongs to what still needs a person.
    //
    // The rail is inside a `ClipRRect` rather than the border itself because
    // Flutter's `Border` refuses non-uniform colours together with a
    // `borderRadius` — the paint call would throw.
    final showRail = !alert.isAcknowledged;

    return Semantics(
      label: '${shortDateTime(alert.raisedAt)}, ${alert.name}, '
          '${alert.isAcknowledged ? 'diakui' : 'belum diakui'}, $summary',
      excludeSemantics: true,
      child: DecoratedBox(
        key: ValueKey('alert-${alert.id}'),
        decoration: BoxDecoration(
          color: surfaces.card,
          borderRadius: BorderRadius.circular(FlowRadius.card),
          border: Border.all(color: surfaces.roadLine),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(FlowRadius.card),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showRail) Container(width: 3, color: accent),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                shortDateTime(alert.raisedAt),
                                style: text.bodySmall
                                    ?.copyWith(color: surfaces.textSecondary),
                              ),
                            ),
                            _AckPill(isAcknowledged: alert.isAcknowledged),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(alert.name, style: text.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          style: text.bodySmall
                              ?.copyWith(color: surfaces.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Left-rail colour by alert level. `macet` uses the semantic emergency red
  /// rather than the congestion `macet` — this rail is severity signalling,
  /// not a congestion state, and using two different reds side by side is
  /// what the palette rules are there to prevent.
  Color _accentColor(BuildContext context, CongestionLevel level) {
    return switch (level) {
      CongestionLevel.macet => FlowSemantics.of(context).emergency,
      CongestionLevel.padat => CongestionColors.of(context).padat,
      _ => FlowSurfaces.of(context).roadLine,
    };
  }
}

/// Whether a person has seen this one.
///
/// The unacknowledged state carries the attention colour, not the
/// acknowledged one. The reference image has it the other way round — a green
/// `Diakui` and a grey `Belum diakui` — which puts the emphasis on the rows
/// that need nothing. Green is also spoken for by `Lancar`.
class _AckPill extends StatelessWidget {
  const _AckPill({required this.isAcknowledged});

  final bool isAcknowledged;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final colors = CongestionColors.of(context);
    final pill = isAcknowledged ? colors.unknownPill : surfaces.errorPill;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: pill.tint,
        borderRadius: BorderRadius.circular(FlowRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          isAcknowledged ? 'Diakui' : 'Belum diakui',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: pill.ink, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// One scrollable row of chips: time, intersection, status.
class _Filters extends StatelessWidget {
  const _Filters({
    required this.filter,
    required this.intersections,
    required this.onChanged,
  });

  final AlertFilter filter;
  final Map<String, String> intersections;
  final ValueChanged<AlertFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);

    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _Chip(
            key: const ValueKey('filter-window'),
            label: filter.window.label,
            onTap: () => _pickWindow(context),
          ),
          const SizedBox(width: 8),
          _Chip(
            key: const ValueKey('filter-camera'),
            label: filter.cameraId == null
                ? 'Semua simpang'
                : intersections[filter.cameraId] ?? 'Simpang',
            onTap: () => _pickCamera(context),
          ),
          const SizedBox(width: 8),
          _Chip(
            key: const ValueKey('filter-ack'),
            label: filter.ack.label,
            onTap: () => _pickAck(context),
          ),
          const SizedBox(width: 8),
          // A hairline so the row reads as a strip rather than floating.
          VerticalDivider(width: 1, color: surfaces.roadLine),
        ],
      ),
    );
  }

  Future<void> _pickWindow(BuildContext context) async {
    final choice = await _sheet<AlertWindow>(
      context,
      'Rentang waktu',
      {for (final w in AlertWindow.values) w.label: w},
    );
    if (choice != null) onChanged(filter.copyWith(window: choice));
  }

  Future<void> _pickAck(BuildContext context) async {
    final choice = await _sheet<AlertAckFilter>(
      context,
      'Status',
      {for (final a in AlertAckFilter.values) a.label: a},
    );
    if (choice != null) onChanged(filter.copyWith(ack: choice));
  }

  Future<void> _pickCamera(BuildContext context) async {
    final choice = await _sheet<String>(
      context,
      'Simpang',
      {
        'Semua simpang': '',
        for (final entry in intersections.entries) entry.value: entry.key,
      },
    );
    if (choice == null) return;
    onChanged(
      choice.isEmpty
          ? filter.copyWith(clearCamera: true)
          : filter.copyWith(cameraId: choice),
    );
  }

  Future<T?> _sheet<T>(
    BuildContext context,
    String title,
    Map<String, T> options,
  ) =>
      showModalBottomSheet<T>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final entry in options.entries)
                ListTile(
                  title: Text(entry.key),
                  onTap: () => Navigator.of(context).pop(entry.value),
                ),
            ],
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: surfaces.card,
          borderRadius: BorderRadius.circular(FlowRadius.control),
          border: Border.all(color: surfaces.roadLine),
        ),
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
