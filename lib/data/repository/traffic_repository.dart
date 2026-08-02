import 'dart:async';

import '../../core/api_exception.dart';
import '../../core/clock.dart';
import '../../core/config/app_config.dart';
import '../../domain/congestion.dart';
import '../api/flowsense_api.dart';
import '../cache/snapshot_cache.dart';
import '../models/traffic_snapshot.dart';

/// What the UI knows at any moment. Sealed, so a widget that forgets a case
/// fails to compile rather than rendering a blank screen.
sealed class RepoState {
  const RepoState();
}

/// Nothing to show yet — before the cache read and the first poll resolve.
final class RepoLoading extends RepoState {
  const RepoLoading();
}

final class RepoData extends RepoState {
  const RepoData({
    required this.snapshot,
    required this.isStale,
    required this.isFromCache,
  });

  final TrafficSnapshot snapshot;

  /// The whole feed is behind — every record is older than `staleAfter`.
  /// Individual dead cameras are judged per record by the marker layer.
  final bool isStale;

  /// Served from disk, not from the network. Always also [isStale] unless the
  /// app was reopened within `staleAfter` of the last good poll.
  final bool isFromCache;
}

/// A poll failed. [lastGood] is whatever was on screen before, so the UI keeps
/// rendering it under a staleness banner instead of blanking.
final class RepoError extends RepoState {
  const RepoError({required this.message, this.lastGood});

  final String message;
  final TrafficSnapshot? lastGood;
}

/// Polls [FlowSenseApi] on a cadence and narrates the result as [RepoState].
///
/// The behaviour that matters: **a transient poll failure must not blank the
/// screen.** This is the mobile mirror of the connector's `ReconnectingStream`
/// — degrade visibly, never go dark.
class TrafficRepository {
  TrafficRepository({
    required this.api,
    required this.config,
    this.clock = const SystemClock(),
    this.cache,
  });

  // Injected dependencies, read-only after construction. Named parameters
  // cannot be private in Dart, so these stay public rather than acquiring four
  // `prefer_initializing_formals` ignores.
  final FlowSenseApi api;
  final AppConfig config;
  final Clock clock;
  final SnapshotCache? cache;

  /// Polling starts on first listen, not at construction: a repository nobody
  /// is watching must not hold the network open. `onListen` also guarantees the
  /// opening `RepoLoading` reaches the subscriber, which a synchronous emit
  /// from the constructor would not.
  late final StreamController<RepoState> _controller =
      StreamController<RepoState>.broadcast(onListen: _onFirstListen);
  StreamSubscription<void>? _ticks;
  TrafficSnapshot? _lastGood;
  bool _started = false;
  bool _disposed = false;

  /// Latest state, replayed to late subscribers so a widget rebuilt mid-poll
  /// does not sit on `RepoLoading` until the next tick.
  RepoState? get current => _current;
  RepoState? _current;

  Stream<RepoState> watch() => _controller.stream;

  void _onFirstListen() {
    if (_started || _disposed) return;
    _started = true;
    unawaited(_start());
  }

  Future<void> _start() async {
    _emit(const RepoLoading());

    // Show the cache first: a cold start on a dead network gets pixels
    // immediately, and a successful first poll overwrites it a moment later.
    final cached = await cache?.read();
    if (_disposed) return;
    if (cached != null) {
      _lastGood = cached;
      _emit(RepoData(
        snapshot: cached,
        isStale: _isStale(cached),
        isFromCache: true,
      ));
    }

    _ticks =
        clock.ticks(config.pollInterval).listen((_) => unawaited(poll()));

    await poll();
  }

  /// One fetch. Public so a pull-to-refresh can force a poll off-cadence.
  Future<void> poll() async {
    if (_disposed) return;
    try {
      final snapshot = await api.snapshot();
      if (_disposed) return;
      _lastGood = snapshot;
      await cache?.save(snapshot);
      if (_disposed) return;
      _emit(RepoData(
        snapshot: snapshot,
        isStale: _isStale(snapshot),
        isFromCache: false,
      ));
    } on ApiException catch (e) {
      if (_disposed) return;
      _emit(RepoError(message: e.message, lastGood: _lastGood));
    }
  }

  /// A snapshot is stale when *no* record in it is fresh. One lagging camera
  /// among healthy ones is a per-marker concern, not a feed-wide banner.
  bool _isStale(TrafficSnapshot snapshot) {
    final now = clock.now();
    if (snapshot.records.isEmpty) {
      return now.difference(snapshot.fetchedAt) > config.staleAfter;
    }
    return snapshot.records
        .every((r) => isStale(r, now, config.staleAfter));
  }

  void _emit(RepoState state) {
    if (_disposed || _controller.isClosed) return;
    _current = state;
    _controller.add(state);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_ticks?.cancel());
    _ticks = null;
    unawaited(_controller.close());
    api.close();
  }
}
