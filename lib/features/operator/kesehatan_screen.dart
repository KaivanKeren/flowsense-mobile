import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/max_width.dart';
import '../../domain/connector_health.dart';
import '../../state/health_providers.dart';
import '../common/failure_state.dart';
import '../common/flow_card.dart';

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
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;
    final health = ref.watch(connectorHealthProvider);

    return Scaffold(
      backgroundColor: surfaces.page,
      body: MaxWidth448(
        child: SafeArea(
          child: Column(
            key: const ValueKey('kesehatan-list'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Modul AI sits above the connector list because the
                    // refinement spec §26 puts AI service health at the top
                    // of the system-health page: if the AI has failed, the
                    // camera vitals below still add up but stop describing
                    // what the system is actually doing.
                    const _AiModelSection(),
                    const SizedBox(height: 20),
                    Text('Kesehatan connector', style: text.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Status perangkat lunak yang memproses citra tiap '
                      'kamera.',
                      style: text.bodyMedium
                          ?.copyWith(color: surfaces.textSecondary),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: surfaces.roadLine),
              Expanded(
                child: switch (health) {
                  AsyncLoading() =>
                    const Center(child: CircularProgressIndicator()),
                  AsyncError() => FailureState(
                      message: 'Status connector tidak dapat dimuat.',
                      actionLabel: 'Coba lagi',
                      onAction: () =>
                          ref.invalidate(connectorHealthProvider),
                    ),
                  AsyncData(:final value) when value.isEmpty =>
                    const FailureState(
                      message: 'Belum ada connector terdaftar.',
                      icon: Icons.sensors_off_outlined,
                    ),
                  AsyncData(:final value) => ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: value.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: surfaces.roadLine),
                      itemBuilder: (context, i) =>
                          _ConnectorRow(health: value[i]),
                    ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AI model health slot (spec §26 & §25).
///
/// Deliberately a placeholder: the health API surfaces only per-connector
/// status right now (see [ConnectorHealth]), and inventing an AI confidence
/// or latency here would fabricate a system-health signal — a screen an
/// operator opens because "something feels wrong" cannot afford invented
/// numbers. When the AI health endpoint lands this widget grows metrics
/// (confidence average, inference latency, model version) inside the same
/// [FlowCard.operational] shell.
class _AiModelSection extends StatelessWidget {
  const _AiModelSection();

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final semantics = FlowSemantics.of(context);
    final text = Theme.of(context).textTheme;

    return FlowCard.operational(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_outlined,
              size: 20, color: semantics.prediction),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Status Modul AI belum tersedia — menunggu integrasi backend.',
              style: text.bodyMedium?.copyWith(color: surfaces.textSecondary),
            ),
          ),
        ],
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
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;
    final detail = healthDetail(health);

    final row = Container(
      key: ValueKey('connector-${health.cameraId}'),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(health.title, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style:
                      text.bodySmall?.copyWith(color: surfaces.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _HealthPill(status: health.status),
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

/// The state, in words.
///
/// A healthy connector gets a neutral pill rather than a green one: green is
/// spoken for by `Lancar`, and the two appear side by side on the dashboard.
/// Anything needing attention gets the one non-congestion red.
class _HealthPill extends StatelessWidget {
  const _HealthPill({required this.status});

  final ConnectorStatus status;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final colors = CongestionColors.of(context);

    final pill = status.needsAttention
        ? surfaces.errorPill
        // The neutral grey pair, borrowed for "nothing to report" — it makes
        // no colour claim, which is the honest thing for a healthy process.
        : colors.unknownPill;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: pill.tint,
        borderRadius: BorderRadius.circular(FlowRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          status.label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: pill.ink, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
