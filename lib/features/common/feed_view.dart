import 'package:flutter/material.dart';

import '../../data/models/traffic_snapshot.dart';
import '../../data/repository/traffic_repository.dart';
import 'relative_time.dart';

/// What a screen should render for one [RepoState], and what to say about it.
///
/// Both flavors answer this question identically — a failed poll keeps the last
/// good data on screen under a banner, a cache read says so, a stale feed says
/// how old it is — so they answer it in one place. Pure, and therefore testable
/// without pumping a widget.
class FeedView {
  const FeedView({required this.snapshot, required this.banner});

  factory FeedView.of(RepoState state, DateTime now) => switch (state) {
        RepoLoading() => const FeedView(snapshot: null, banner: null),
        RepoData(:final snapshot, :final isStale, :final isFromCache) =>
          FeedView(
            snapshot: snapshot,
            banner: isFromCache
                ? 'Data tersimpan. ${lastDataText(snapshot, now)}'
                : isStale
                    ? lastDataText(snapshot, now)
                    : null,
          ),
        RepoError(:final message, :final lastGood) =>
          FeedView(snapshot: lastGood, banner: message),
      };

  /// Null only when there is genuinely nothing to draw — never merely because
  /// the last poll failed.
  final TrafficSnapshot? snapshot;

  /// Non-null when the user deserves to be told the data is not current.
  final String? banner;

  /// Age of the freshest record in [snapshot], in plain Indonesian.
  static String lastDataText(TrafficSnapshot snapshot, DateTime now) {
    final newest = snapshot.records.isEmpty
        ? snapshot.fetchedAt
        : snapshot.records
            .map((r) => r.ts)
            .reduce((a, b) => a.isAfter(b) ? a : b);
    return 'Data terakhir ${relativeIndonesian(now.difference(newest))}';
  }
}

/// Says the numbers on screen are bundled fixtures, not live traffic.
///
/// Shown in the app bar of both flavors whenever no backend is configured. The
/// app degrading to fixtures is what keeps a demo alive on a missing key; doing
/// it *silently* would be passing off canned data as real, which is a different
/// thing entirely.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            'Data contoh',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
          ),
        ),
      ),
    );
  }
}

/// The empty and error states share a shape: what is going on, and what to do
/// about it. Never a bare spinner, and never a dead end.
class QuietState extends StatelessWidget {
  const QuietState({
    super.key,
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
