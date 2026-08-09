import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// One pattern, several variants. Every variant is a single sentence saying
/// what happened, and — when there is one — a single button that does
/// something about it. The button is optional: an empty result is not a
/// failure to retry, so a `noAlerts` state has none.
///
/// **There is no endless spinner in this app.** A spinner says "wait" without
/// saying what for, and on a phone at a junction that is worse than saying
/// nothing.
class FailureState extends StatelessWidget {
  const FailureState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.cloud_off_outlined,
  }) : assert(
          (actionLabel == null) == (onAction == null),
          'actionLabel and onAction must be both set or both omitted',
        );

  /// No connection — the last snapshot is usually still on screen behind this.
  const FailureState.noConnection({
    super.key,
    required String lastDataText,
    required VoidCallback onRetry,
  })  : message = 'Tidak ada koneksi. $lastDataText.',
        actionLabel = 'Coba lagi',
        onAction = onRetry,
        icon = Icons.cloud_off_outlined;

  /// Nothing has arrived from any intersection at all.
  const FailureState.noData({super.key, required VoidCallback onRetry})
      : message = 'Belum ada data masuk dari simpang mana pun.',
        actionLabel = 'Coba lagi',
        onAction = onRetry,
        icon = Icons.sensors_off_outlined;

  /// Location was refused. The button is not "grant permission" — it is the way
  /// on, because the list carries everything the map does.
  const FailureState.locationDenied({super.key, required VoidCallback onOpenList})
      : message =
            'Lokasi tidak diizinkan. Simpang tetap bisa dilihat di daftar.',
        actionLabel = 'Buka daftar',
        onAction = onOpenList,
        icon = Icons.location_off_outlined;

  /// The alert history is empty for the current filter. Deliberately actionless
  /// — an operator changes the filter chips if they want to see more, and a
  /// "Coba lagi" button here would promise something that isn't happening.
  const FailureState.noAlerts({super.key})
      : message = 'Tidak ada peringatan pada rentang ini.',
        actionLabel = null,
        onAction = null,
        icon = Icons.notifications_none_outlined;

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: surfaces.faintInk),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
