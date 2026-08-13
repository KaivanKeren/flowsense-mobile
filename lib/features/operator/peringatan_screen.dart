import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/max_width.dart';
import '../../domain/alert_filter.dart';
import '../../domain/operator_alert.dart';
import '../../state/alert_providers.dart';
import '../../state/providers.dart';
import '../../widgets/widgets.dart';

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
    final colors = AppColors.of(context);
    final now = ref.watch(clockProvider).now();
    final alerts = ref.watch(operatorAlertsProvider);
    final intersections = ref.watch(intersectionsProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: colors.surfaceCanvas,
      appBar: AppBar(
        title: const Text('Peringatan'),
        titleSpacing: FlowSpace.lg,
      ),
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
                // Loading. A skeleton in the shape of the alert rows, so the
                // page says what is coming instead of merely asking for
                // patience.
                AsyncLoading() => const SkeletonList(rows: 5),
                AsyncError() => MessageState.error(
                    title: 'Tidak dapat memuat riwayat',
                    message: 'Riwayat peringatan tidak dapat dimuat.',
                    actionLabel: 'Coba lagi',
                    onAction: () =>
                        ref.invalidate(operatorAlertsProvider),
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
    if (alerts.isEmpty) {
      return MessageState.empty(
        title: 'Tidak ada peringatan',
        message: 'Tidak ada peringatan pada rentang ini.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        FlowSpace.lg,
        FlowSpace.xs,
        FlowSpace.lg,
        FlowSpace.xl,
      ),
      itemCount: alerts.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: FlowSpace.md),
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
    final type = FlowTypography.of(context);
    final summary = alertSummaryLine(alert, now);

    return AppCard(
      key: ValueKey('alert-${alert.id}'),
      padding: const EdgeInsets.all(FlowSpace.md),
      semanticsLabel: '${shortDateTime(alert.raisedAt)}, ${alert.name}, '
          '${alert.isAcknowledged ? 'diakui' : 'belum diakui'}, $summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shortDateTime(alert.raisedAt),
                  style: type.caption,
                ),
              ),
              // Never colour alone. A person glancing at the strip needs the
              // word as much as the tint, which is exactly what StatusChip
              // exists to guarantee.
              StatusChip(
                label: alert.isAcknowledged ? 'Diakui' : 'Belum diakui',
                tone: alert.isAcknowledged
                    ? StatusTone.neutral
                    : StatusTone.emergency,
                semanticsPrefix: null,
              ),
            ],
          ),
          const SizedBox(height: FlowSpace.sm),
          Text(alert.name, style: type.sectionTitle),
          const SizedBox(height: FlowSpace.xs),
          Text(summary, style: type.caption),
        ],
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
    final colors = AppColors.of(context);

    return SizedBox(
      // The floor plus the row's own vertical padding. Anything less and the
      // chips drop below the 48 dp target the rest of the console holds.
      height: FlowTouch.minTarget + FlowSpace.lg,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: FlowSpace.lg,
          vertical: FlowSpace.sm,
        ),
        children: [
          _Chip(
            key: const ValueKey('filter-window'),
            label: filter.window.label,
            onTap: () => _pickWindow(context),
          ),
          const SizedBox(width: FlowSpace.sm),
          _Chip(
            key: const ValueKey('filter-camera'),
            label: filter.cameraId == null
                ? 'Semua simpang'
                : intersections[filter.cameraId] ?? 'Simpang',
            onTap: () => _pickCamera(context),
          ),
          const SizedBox(width: FlowSpace.sm),
          _Chip(
            key: const ValueKey('filter-ack'),
            label: filter.ack.label,
            onTap: () => _pickAck(context),
          ),
          const SizedBox(width: FlowSpace.sm),
          // A hairline so the row reads as a strip rather than floating.
          VerticalDivider(width: 1, color: colors.borderSubtle),
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
                padding: const EdgeInsets.all(FlowSpace.lg),
                child: Text(title, style: FlowTypography.of(context).sectionTitle),
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
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: FlowTouch.minTarget),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: FlowSpace.md),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(FlowRadius.sm),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Text(label, style: type.body),
        ),
      ),
    );
  }
}
