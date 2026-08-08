import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/max_width.dart';
import '../../domain/connector_health.dart';
import '../../state/health_providers.dart';

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
                  AsyncError() => _CouldNotLoad(
                      onRetry: () => ref.invalidate(connectorHealthProvider),
                    ),
                  AsyncData(:final value) when value.isEmpty => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Belum ada connector terdaftar.',
                          style: text.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
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

class _CouldNotLoad extends StatelessWidget {
  const _CouldNotLoad({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Status connector tidak dapat dimuat.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
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
