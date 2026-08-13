import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/max_width.dart';
import '../../domain/connector_health.dart';
import '../../state/health_providers.dart';
import '../../widgets/widgets.dart';

/// Are the connectors alive?
///
/// The screen an operator opens when something feels wrong, and the only place
/// in the console where "the road is genuinely quiet" can be told apart from
/// "the process died". Those look identical on a traffic map and they call for
/// opposite responses, which is why the layout spec refuses to fold this into
/// the dashboard.
class KesehatanScreen extends ConsumerWidget {
  const KesehatanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);
    final health = ref.watch(connectorHealthProvider);

    return Scaffold(
      backgroundColor: colors.surfaceCanvas,
      appBar: AppBar(
        title: const Text('Kesehatan'),
        titleSpacing: FlowSpace.lg,
      ),
      body: MaxWidth448(
        child: Column(
          key: const ValueKey('kesehatan-list'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FlowSpace.lg,
                FlowSpace.sm,
                FlowSpace.lg,
                FlowSpace.sm,
              ),
              child: Text(
                'Status perangkat lunak yang memproses citra tiap kamera.',
                style: type.caption.copyWith(color: colors.textSecondary),
              ),
            ),
            Expanded(
              child: switch (health) {
                // Loading. A skeleton in the shape of the connector rows, so
                // the page says what is coming instead of asking for patience.
                AsyncLoading() => const SkeletonList(rows: 5),
                AsyncError() => MessageState.error(
                    title: 'Tidak dapat memuat status',
                    message: 'Status connector tidak dapat dimuat.',
                    actionLabel: 'Coba lagi',
                    onAction: () => ref.invalidate(connectorHealthProvider),
                  ),
                AsyncData(:final value) when value.isEmpty =>
                  const MessageState.empty(
                    title: 'Belum ada connector',
                    message: 'Belum ada connector terdaftar.',
                  ),
                AsyncData(:final value) => ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: value.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colors.borderSubtle),
                    itemBuilder: (context, i) =>
                        _ConnectorRow(health: value[i]),
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

/// Identity on the first line, vitals on the second.
///
/// A stopped connector is dimmed for the same reason a stale intersection is:
/// a row you cannot act on should not compete with the ones you can. It is not
/// hidden, though — a connector that stopped is precisely what somebody came
/// here to find.
class _ConnectorRow extends StatelessWidget {
  const _ConnectorRow({required this.health});

  final ConnectorHealth health;

  @override
  Widget build(BuildContext context) {
    final type = FlowTypography.of(context);
    final detail = healthDetail(health);

    final row = Container(
      key: ValueKey('connector-${health.cameraId}'),
      constraints: const BoxConstraints(minHeight: FlowTouch.minTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: FlowSpace.lg,
        vertical: FlowSpace.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(health.title, style: type.sectionTitle),
                const SizedBox(height: FlowSpace.xs),
                Text(detail, style: type.caption),
              ],
            ),
          ),
          const SizedBox(width: FlowSpace.md),
          StatusChip(
            label: health.status.label,
            tone: _toneFor(health.status),
            // No prefix: the row's own Semantics already says which connector
            // this is, and repeating it would have a screen reader announce
            // the name twice.
            semanticsPrefix: null,
          ),
        ],
      ),
    );

    return Semantics(
      label: '${health.title}, ${health.status.label.toLowerCase()}, $detail',
      excludeSemantics: true,
      child: health.status == ConnectorStatus.berhenti
          ? Opacity(opacity: 0.6, child: row)
          : row,
    );
  }
}

/// The state, in words, at the severity the palette assigns it.
///
/// A healthy connector gets a neutral chip rather than a green one: green is
/// spoken for by `Lancar`, and the two appear side by side on the dashboard.
/// A connector still running but losing records gets the warning tone, and one
/// that has stopped gets the attention red — never the congestion hues, which
/// are reserved for road conditions.
StatusTone _toneFor(ConnectorStatus status) => switch (status) {
      ConnectorStatus.berjalan => StatusTone.neutral,
      ConnectorStatus.terputus => StatusTone.warning,
      ConnectorStatus.berhenti => StatusTone.emergency,
    };
