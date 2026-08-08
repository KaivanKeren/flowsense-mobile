import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/traffic_repository.dart';
import '../../state/auth_providers.dart';
import '../../state/providers.dart';

/// Ends the session the moment the backend stops honouring the token.
///
/// A 401 is never retried — that rule has existed since the API client was
/// written, and this is what gives it a purpose. Without this, an expired
/// token leaves the console polling forever against a session that is gone,
/// papering the screen with errors it cannot recover from and quietly hiding
/// the fact that the operator is no longer signed in.
///
/// Wiring, not chrome: it renders [child] and nothing of its own.
class SessionWatcher extends ConsumerWidget {
  const SessionWatcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<RepoState>>(snapshotProvider, (_, next) {
      final state = next.valueOrNull;
      if (state is! RepoError) return;
      if (state.statusCode != 401) return;

      // Stop the poller before clearing the token, so no further request goes
      // out carrying a credential the server has already rejected.
      ref.read(repositoryProvider).dispose();
      unawaited(ref.read(authProvider.notifier).expire());
    });

    return child;
  }
}
